import Combine
import Foundation
import SwiftData

@MainActor
final class ExplorerStore: ObservableObject {
  @Published private(set) var quests: [QuestDefinition] = []
  @Published private(set) var currentQuest: QuestDefinition?
  @Published private(set) var catalogVersion = "—"
  @Published private(set) var catalogError: String?
  @Published private(set) var selectedState: ExplorerState?
  @Published private(set) var activeContexts: [String] = ["Anywhere"]
  @Published private(set) var contextProfile: ContextProfile?
  @Published private(set) var recommendationUnavailable = false
  @Published private(set) var recentEvents: [QuestEventRecord] = []
  @Published private(set) var lastRecommendationSource = "—"
  @Published private(set) var lastRecommendationScore = "—"
  @Published private(set) var diagnostics: [String] = []
  @Published var hasSeenIntro: Bool
  @Published var isExplorePresented = false
  @Published var isLabPresented = false
  @Published var isSkipHelpPresented = false
  @Published var isFeedbackPresented = false
  @Published private(set) var exportURL: URL?
  @Published private(set) var exportError: String?

  private let modelContext: ModelContext
  private let persistence: SessionPersistence
  private var catalog: BundledQuestCatalog?
  private var recommendationEngine: RecommendationEngineV1?
  private var recommendationConfiguration: RecommendationConfiguration?
  private var snapshot: QuestSessionSnapshot
  private var pendingSkipQuest: QuestDefinition?
  private var started = false
  private var openExploreAfterSkipDismissal = false
  private let clock: () -> Date
  private let randomSeed: () -> UInt64

  var surface: AppSurface {
    if !hasSeenIntro { return .intro }
    if isFeedbackPresented { return .feedback }
    if isSkipHelpPresented { return .skipHelp }
    if isLabPresented { return .lab }
    if isExplorePresented { return .explore }
    return .home
  }

  init(
    modelContext: ModelContext,
    persistence providedPersistence: SessionPersistence? = nil,
    storageDiagnostic: String? = nil,
    clock: @escaping () -> Date = Date.init,
    randomSeed: @escaping () -> UInt64 = { UInt64.random(in: UInt64.min...UInt64.max) }
  ) {
    self.clock = clock
    self.randomSeed = randomSeed
    self.modelContext = modelContext
    let persistence = providedPersistence ?? SessionPersistence()
    self.persistence = persistence
    hasSeenIntro = persistence.hasSeenIntro
    snapshot = persistence.load() ?? QuestSessionSnapshot()

    if let storageDiagnostic {
      diagnostics.append(storageDiagnostic)
    }

    do {
      let catalog = try BundledQuestCatalog()
      let configuration = try RecommendationConfiguration.bundled()
      self.catalog = catalog
      recommendationConfiguration = configuration
      recommendationEngine = RecommendationEngineV1(configuration: configuration)
      quests = catalog.quests
      catalogVersion = catalog.catalogVersion
      currentQuest = snapshot.activeQuestID.flatMap(catalog.quest(id:))
      selectedState = snapshot.selectedState
      activeContexts = snapshot.activeContexts
      contextProfile = snapshot.contextProfile
    } catch {
      catalogError = error.localizedDescription
      diagnostics.append("目录载入失败：\(error.localizedDescription)")
    }

    refreshRecentEvents()
  }

  func startIfNeeded(now: Date = Date()) {
    guard !started else { return }
    started = true
    appendEvent(.appOpened, quest: currentQuest, timestamp: now)
    guard hasSeenIntro, catalog != nil else { return }
    resume(now: now)
  }

  func completeIntro(now: Date = Date()) {
    persistence.hasSeenIntro = true
    hasSeenIntro = true
    if currentQuest == nil || snapshot.sessionID == nil {
      startNewSession(now: now)
    }
  }

  func resetIntro() {
    persistence.hasSeenIntro = false
    persistence.clearSession()
    hasSeenIntro = false
    snapshot = QuestSessionSnapshot()
    currentQuest = nil
    selectedState = nil
    activeContexts = snapshot.activeContexts
    contextProfile = nil
    isLabPresented = false
  }

  func appDidEnterBackground(now: Date = Date()) {
    guard started else { return }
    snapshot.lastBackgroundedAt = now
    snapshot.lastActivityAt = now
    snapshot.backgroundSurface = surface
    persistSnapshot()
    appendEvent(.appBackgrounded, quest: currentQuest, timestamp: now)
  }

  func appDidBecomeActive(now: Date = Date()) {
    guard started, hasSeenIntro else { return }
    resume(now: now)
  }

  private func resume(now: Date) {
    let backgroundedAt = snapshot.lastBackgroundedAt
    let alreadyHandled =
      snapshot.feedbackPromptDismissedSeedID == currentQuest?.id
      || hasFeedbackForCurrentQuest()
    if snapshot.pendingReflection == nil, snapshot.backgroundSurface == .home,
      let sessionID = snapshot.sessionID, let quest = currentQuest,
      SessionPolicy.shouldOfferFeedback(
        backgroundedAt: backgroundedAt,
        now: now,
        hasActiveQuest: currentQuest != nil,
        wasSkipped: snapshot.currentServeSkipped,
        alreadyHandled: alreadyHandled
      )
    {
      snapshot.pendingReflection = ReflectionCandidate(
        sessionID: sessionID, seedID: quest.id,
        selectedState: selectedState, contextProfile: contextProfile)
    }
    // A deliberately skipped/empty focus is still part of the current session.
    let sessionQuestID = currentQuest?.id ?? (snapshot.currentServeSkipped ? -1 : nil)
    if SessionPolicy.shouldStartNewSession(
      activeQuestID: sessionQuestID,
      lastBackgroundedAt: backgroundedAt, lastActivityAt: snapshot.lastActivityAt, now: now)
    {
      startNewSession(now: now)
    }
    snapshot.lastBackgroundedAt = nil
    snapshot.backgroundSurface = nil
    snapshot.lastActivityAt = now
    persistSnapshot()
    if currentQuest == nil && snapshot.currentServeSkipped && !isSkipHelpPresented
      && !isExplorePresented
    {
      updateState(.doNothing)
      serveRecommended(source: "skip_pause")
    }
    presentFeedbackIfPossible()
  }

  func presentFeedbackIfPossible() {
    guard snapshot.pendingReflection != nil, surface == .home else { return }
    isFeedbackPresented = true
  }

  func feedbackPromptDidAppear() {
    guard let candidate = snapshot.pendingReflection,
      !hasEvent(.attentionShiftPromptShown, candidate: candidate)
    else { return }
    appendReflectionEvent(.attentionShiftPromptShown, candidate: candidate)
  }

  func selectState(_ state: ExplorerState?) {
    guard selectedState != state else { return }
    updateState(state)
    serveRecommended(source: "state_change")
  }

  private func updateState(_ state: ExplorerState?) {
    guard selectedState != state else { return }
    snapshot.selectedState = state
    snapshot.consecutiveSkips = 0
    selectedState = state
    persistSnapshot()
    appendEvent(
      .stateChanged,
      quest: currentQuest,
      source: state == nil ? "cleared" : "selected",
      selectedState: state
    )
  }

  func selectContext(_ profile: ContextProfile?) {
    guard contextProfile != profile
      || (profile == .night && !activeContexts.contains("Safe Lit Space")) else { return }
    snapshot.contextProfile = profile
    contextProfile = profile
    activeContexts = profile?.confirmedContexts.sorted() ?? ["Anywhere"]
    snapshot.activeContexts = activeContexts
    persistSnapshot()
    appendEvent(
      .contextChanged, quest: currentQuest, source: profile == nil ? "cleared" : "selected")
  }

  func skipCurrent() {
    guard let quest = currentQuest else { return }
    let nextCount = snapshot.consecutiveSkips + 1
    snapshot.consecutiveSkips = nextCount
    snapshot.currentServeSkipped = true
    snapshot.activeQuestID = nil
    currentQuest = nil
    pendingSkipQuest = quest
    persistSnapshot()
    appendEvent(.questSkipped, quest: quest, source: "one_tap", selectedState: selectedState)
    switch SkipPolicy.action(
      afterConsecutiveSkipCount: nextCount,
      limit: recommendationConfiguration?.guardrails.maxDefaultRerollsBeforeStatePrompt ?? 0)
    {
    case .replaceImmediately:
      serveRecommended(source: "skip_replacement")
      pendingSkipQuest = nil
    case .askForReason:
      isSkipHelpPresented = true
    }
  }

  func resolvePendingSkip(reason: SkipReason) {
    guard let rejected = pendingSkipQuest else { return }
    appendEvent(
      .skipReasonSelected, quest: rejected, source: "reason_prompt",
      selectedState: selectedState, skipReason: reason)
    pendingSkipQuest = nil
    isSkipHelpPresented = false
    if reason == .notNow { updateState(.doNothing) }
    if reason == .contextMismatch { selectContext(nil) }
    snapshot.consecutiveSkips = 0
    persistSnapshot()
    serveRecommended(source: "skip_replacement", adjustment: reason, rejectedWorld: rejected.world)
  }

  func chooseStateFromSkip(_ state: ExplorerState) {
    guard pendingSkipQuest != nil else { return }
    pendingSkipQuest = nil
    isSkipHelpPresented = false
    updateState(state)
    snapshot.consecutiveSkips = 0
    serveRecommended(source: "state_change")
  }

  func openExploreFromSkip() {
    pendingSkipQuest = nil
    openExploreAfterSkipDismissal = true
    isSkipHelpPresented = false
  }

  func skipHelpDidDismiss() {
    if pendingSkipQuest != nil {
      pendingSkipQuest = nil
      updateState(.doNothing)
      serveRecommended(source: "skip_pause")
    }
    if openExploreAfterSkipDismissal {
      openExploreAfterSkipDismissal = false
      isExplorePresented = true
    }
  }

  func selectFromLibrary(
    _ quest: QuestDefinition,
    source: String,
    sourceDetail: String
  ) {
    if source == "explore_state",
      let state = ExplorerState.allCases.first(where: { $0.sourceDetail == sourceDetail })
    {
      updateState(state)
    }
    if source == "explore_context", let profile = ContextProfile(rawValue: sourceDetail) {
      selectContext(profile)
    }
    appendEvent(
      .questSelectedFromLibrary,
      quest: quest,
      source: source,
      sourceDetail: sourceDetail,
      selectedState: selectedState
    )
    snapshot.consecutiveSkips = 0
    serve(quest, source: source, scoreSummary: "用户从有限书架中选择", sourceDetail: sourceDetail)
    isExplorePresented = false
  }

  func recordTaste(more: Bool) {
    guard let currentQuest else { return }
    appendEvent(
      more ? .moreLikeThis : .lessLikeThis,
      quest: currentQuest,
      source: "quest_menu",
      selectedState: selectedState
    )
  }

  func submitFeedback(_ value: FeedbackValue) {
    guard let candidate = snapshot.pendingReflection else { return }
    appendReflectionEvent(.attentionShiftFeedback, candidate: candidate, feedbackValue: value)
    finishFeedback(candidate)
  }

  func dismissFeedback() {
    guard let candidate = snapshot.pendingReflection else { return }
    appendReflectionEvent(.attentionShiftDismissed, candidate: candidate)
    finishFeedback(candidate)
  }

  private func finishFeedback(_ candidate: ReflectionCandidate) {
    if snapshot.sessionID == candidate.sessionID {
      snapshot.feedbackPromptDismissedSeedID = candidate.seedID
    }
    snapshot.pendingReflection = nil
    persistSnapshot()
    isFeedbackPresented = false
  }

  func exportEvents(now: Date = Date(), directory: URL? = nil) {
    do {
      exportURL = try EventExporter.write(
        records: fetchEvents(ascending: true),
        catalogVersion: catalogVersion,
        recommendationVersion: recommendationConfiguration?.version ?? "unknown",
        now: now,
        directory: directory
      )
      appendEvent(.eventLogExported, quest: currentQuest, source: "lab", timestamp: now)
      exportError = nil
    } catch {
      exportURL = nil
      exportError = error.localizedDescription
      diagnostics.append("事件导出失败：\(error.localizedDescription)")
    }
  }

  private func startNewSession(now: Date) {
    let reflection = snapshot.pendingReflection
    snapshot = QuestSessionSnapshot(
      sessionID: UUID(), lastActivityAt: now, pendingReflection: reflection)
    selectedState = nil
    activeContexts = snapshot.activeContexts
    contextProfile = nil
    currentQuest = nil
    persistSnapshot()
    appendEvent(.sessionStarted, source: "session_default", timestamp: now)
    serveRecommended(source: "session_default")
  }

  private func serveRecommended(
    source: String,
    adjustment: SkipReason? = nil,
    rejectedWorld: String? = nil
  ) {
    guard let recommendationEngine, let recommendationConfiguration else { return }
    var context = makeRecommendationContext(
      cooldownDays: recommendationConfiguration.guardrails.sameSeedCooldownDays
    )
    apply(adjustment: adjustment, to: &context)
    if adjustment == .tasteMismatch, let rejectedWorld { context.avoidedWorlds = [rejectedWorld] }

    guard let result = recommendationEngine.recommend(from: quests, context: context) else {
      diagnostics.append("推荐失败：没有符合当前过滤条件的 Quest")
      currentQuest = nil
      snapshot.activeQuestID = nil
      recommendationUnavailable = true
      persistSnapshot()
      return
    }
    let serendipity = result.usedSerendipity ? " · controlled serendipity" : ""
    serve(
      result.quest,
      source: source,
      scoreSummary: String(
        format: "%.1f · %@%@ · fallback %d", result.totalScore, result.scoreSummary, serendipity,
        result.fallbackLevel),
      result: result
    )
  }

  private func serve(
    _ quest: QuestDefinition,
    source: String,
    scoreSummary: String,
    sourceDetail: String? = nil,
    result: RecommendationResult? = nil
  ) {
    currentQuest = quest
    recommendationUnavailable = false
    snapshot.lastActivityAt = clock()
    snapshot.activeQuestID = quest.id
    snapshot.currentServeSkipped = false
    snapshot.feedbackPromptDismissedSeedID = nil
    persistSnapshot()
    lastRecommendationSource = source
    lastRecommendationScore = scoreSummary
    appendEvent(
      .questServed,
      quest: quest,
      source: source,
      sourceDetail: sourceDetail,
      selectedState: selectedState,
      result: result
    )
  }

  private func makeRecommendationContext(cooldownDays: Int) -> RecommendationContext {
    let cutoff = clock().addingTimeInterval(-Double(cooldownDays) * 86_400)
    let served = fetchEvents(ascending: false)
      .filter { $0.type == QuestEventType.questServed.rawValue }
    let recentForDiversity = Array(served.prefix(7).reversed())
    let allowedMovement: Set<String> =
      selectedState == .move
      ? ["Stay Here", "Few Steps", "Under 50m", "Short Walk"]
      : ["Stay Here", "Few Steps"]

    return RecommendationContext(
      selectedState: selectedState,
      allowedMovement: allowedMovement,
      activeContexts: Set(activeContexts),
      contextProfile: contextProfile,
      lastServedAt: Dictionary(
        served.compactMap { event in event.seedID.map { ($0, event.timestamp) } },
        uniquingKeysWith: max),
      latestSeedIDs: Set(served.prefix(2).compactMap(\.seedID)),
      recentSeedIDs: Set(served.filter { $0.timestamp >= cutoff }.compactMap(\.seedID)),
      recentWorlds: recentForDiversity.compactMap(\.world),
      recentCanonicalLenses: recentForDiversity.compactMap(\.canonicalLens),
      recentFindHeavy: recentForDiversity.map { event in
        guard let seedID = event.seedID else { return false }
        return catalog?.quest(id: seedID)?.isFindHeavy ?? false
      },
      randomSeed: randomSeed()
    )
  }

  private func apply(
    adjustment: SkipReason?,
    to context: inout RecommendationContext
  ) {
    guard let adjustment else { return }
    switch adjustment {
    case .contextMismatch:
      context.avoidContextSpecific = true
    case .movementMismatch:
      context.allowedMovement = ["Stay Here"]
    case .tooMuchEffort:
      context.maximumCognitiveLoad = "Low"
    case .tasteMismatch:
      if let world = currentQuest?.world { context.avoidedWorlds = [world] }
    case .notNow:
      break
    }
  }

  private func hasFeedbackForCurrentQuest() -> Bool {
    guard let currentQuest, let sessionID = snapshot.sessionID else { return false }
    let candidate = ReflectionCandidate(
      sessionID: sessionID, seedID: currentQuest.id,
      selectedState: selectedState, contextProfile: contextProfile)
    return hasEvent(.attentionShiftFeedback, candidate: candidate)
      || hasEvent(.attentionShiftDismissed, candidate: candidate)
  }

  private func hasEvent(_ type: QuestEventType, candidate: ReflectionCandidate) -> Bool {
    let eventType = type.rawValue
    let sessionID = candidate.sessionID
    let seedID = candidate.seedID
    var descriptor = FetchDescriptor<QuestEventRecord>(
      predicate: #Predicate {
        $0.type == eventType && $0.sessionID == sessionID && $0.seedID == seedID
      })
    descriptor.fetchLimit = 1
    do { return try !modelContext.fetch(descriptor).isEmpty } catch {
      diagnostics.append("反馈查询失败：\(error.localizedDescription)")
      return false
    }
  }

  private func appendReflectionEvent(
    _ type: QuestEventType, candidate: ReflectionCandidate,
    feedbackValue: FeedbackValue? = nil
  ) {
    let record = QuestEventRecord(
      timestamp: clock(), type: type, sessionID: candidate.sessionID,
      quest: catalog?.quest(id: candidate.seedID), source: "return_prompt",
      selectedState: candidate.selectedState, feedbackValue: feedbackValue)
    record.contextProfile = candidate.contextProfile?.rawValue
    record.surface = AppSurface.feedback.rawValue
    record.recommendationVersion = recommendationConfiguration?.version
    saveEvent(record)
  }

  private func appendEvent(
    _ type: QuestEventType,
    quest: QuestDefinition? = nil,
    source: String? = nil,
    sourceDetail: String? = nil,
    selectedState: ExplorerState? = nil,
    skipReason: SkipReason? = nil,
    feedbackValue: FeedbackValue? = nil,
    timestamp: Date? = nil,
    result: RecommendationResult? = nil
  ) {
    let record = QuestEventRecord(
      timestamp: timestamp ?? clock(),
      type: type,
      sessionID: snapshot.sessionID,
      quest: quest,
      source: source,
      selectedState: selectedState,
      skipReason: skipReason,
      feedbackValue: feedbackValue
    )
    record.sourceDetail = sourceDetail
    record.surface = surface.rawValue
    record.contextProfile = contextProfile?.rawValue
    record.recommendationVersion = recommendationConfiguration?.version
    record.recommendationScore = result?.totalScore
    record.usedSerendipity = result?.usedSerendipity
    record.fallbackLevel = result?.fallbackLevel
    saveEvent(record)
  }

  private func saveEvent(_ record: QuestEventRecord) {
    modelContext.insert(record)
    do {
      try modelContext.save()
    } catch {
      diagnostics.append("事件保存失败：\(error.localizedDescription)")
    }
    refreshRecentEvents()
  }

  private func fetchEvents(ascending: Bool, limit: Int? = nil) -> [QuestEventRecord] {
    let order: SortOrder = ascending ? .forward : .reverse
    var descriptor = FetchDescriptor<QuestEventRecord>(
      sortBy: [SortDescriptor(\.timestamp, order: order)]
    )
    descriptor.fetchLimit = limit
    do {
      return try modelContext.fetch(descriptor)
    } catch {
      diagnostics.append("事件读取失败：\(error.localizedDescription)")
      return []
    }
  }

  private func refreshRecentEvents() {
    recentEvents = fetchEvents(ascending: false, limit: 40)
  }

  private func persistSnapshot() {
    persistence.save(snapshot)
  }
}
