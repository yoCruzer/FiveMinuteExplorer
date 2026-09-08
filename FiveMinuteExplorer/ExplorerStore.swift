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

  init(
    modelContext: ModelContext,
    persistence providedPersistence: SessionPersistence? = nil,
    storageDiagnostic: String? = nil
  ) {
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
    } catch {
      catalogError = error.localizedDescription
      diagnostics.append("目录载入失败：\(error.localizedDescription)")
    }

    refreshRecentEvents()
  }

  func startIfNeeded(now: Date = Date()) {
    guard !started else { return }
    started = true
    appendEvent(.appOpened, quest: currentQuest)
    guard hasSeenIntro, catalog != nil else { return }

    if SessionPolicy.shouldStartNewSession(
      activeQuestID: currentQuest?.id,
      lastBackgroundedAt: snapshot.lastBackgroundedAt,
      now: now
    ) {
      startNewSession(now: now)
    }
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
    isLabPresented = false
  }

  func appDidEnterBackground(now: Date = Date()) {
    guard started else { return }
    snapshot.lastBackgroundedAt = now
    persistSnapshot()
    appendEvent(.appBackgrounded, quest: currentQuest, timestamp: now)
  }

  func appDidBecomeActive(now: Date = Date()) {
    guard started, hasSeenIntro else { return }
    let backgroundedAt = snapshot.lastBackgroundedAt

    if SessionPolicy.shouldStartNewSession(
      activeQuestID: currentQuest?.id,
      lastBackgroundedAt: backgroundedAt,
      now: now
    ) {
      startNewSession(now: now)
      return
    }

    let alreadyHandled =
      snapshot.feedbackPromptDismissedSeedID == currentQuest?.id
      || hasFeedbackForCurrentQuest()
    if SessionPolicy.shouldOfferFeedback(
      backgroundedAt: backgroundedAt,
      now: now,
      hasActiveQuest: currentQuest != nil,
      wasSkipped: snapshot.currentServeSkipped,
      alreadyHandled: alreadyHandled
    ) {
      isFeedbackPresented = true
    }

    snapshot.lastBackgroundedAt = nil
    persistSnapshot()
  }

  func selectState(_ state: ExplorerState?) {
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
    serveRecommended(source: "state_change")
  }

  func skipCurrent() {
    guard let quest = currentQuest else { return }
    let nextCount = snapshot.consecutiveSkips + 1
    switch SkipPolicy.action(afterConsecutiveSkipCount: nextCount) {
    case .replaceImmediately:
      snapshot.consecutiveSkips = nextCount
      snapshot.currentServeSkipped = true
      persistSnapshot()
      appendEvent(.questSkipped, quest: quest, source: "one_tap")
      serveRecommended(source: "skip_replacement")
    case .askForReason:
      pendingSkipQuest = quest
      isSkipHelpPresented = true
    }
  }

  func resolvePendingSkip(reason: SkipReason) {
    guard commitPendingSkip(reason: reason) else { return }
    isSkipHelpPresented = false
    guard reason != .notNow else { return }
    snapshot.consecutiveSkips = 0
    persistSnapshot()
    serveRecommended(source: "skip_replacement", adjustment: reason)
  }

  func chooseStateFromSkip(_ state: ExplorerState) {
    _ = commitPendingSkip(reason: nil)
    isSkipHelpPresented = false
    selectState(state)
  }

  func openExploreFromSkip() {
    _ = commitPendingSkip(reason: nil)
    openExploreAfterSkipDismissal = true
    isSkipHelpPresented = false
  }

  func skipHelpDidDismiss() {
    _ = commitPendingSkip(reason: nil)
    if openExploreAfterSkipDismissal {
      openExploreAfterSkipDismissal = false
      isExplorePresented = true
    }
  }

  func selectFromLibrary(
    _ quest: QuestDefinition,
    source: String
  ) {
    appendEvent(
      .questSelectedFromLibrary,
      quest: quest,
      source: source,
      selectedState: selectedState
    )
    snapshot.consecutiveSkips = 0
    serve(quest, source: source, scoreSummary: "用户从有限书架中选择")
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
    guard let currentQuest else { return }
    appendEvent(
      .attentionShiftFeedback,
      quest: currentQuest,
      source: "return_prompt",
      selectedState: selectedState,
      feedbackValue: value
    )
    snapshot.feedbackPromptDismissedSeedID = currentQuest.id
    persistSnapshot()
    isFeedbackPresented = false
  }

  func dismissFeedback() {
    snapshot.feedbackPromptDismissedSeedID = currentQuest?.id
    persistSnapshot()
    isFeedbackPresented = false
  }

  func exportEvents(now: Date = Date()) {
    appendEvent(.eventLogExported, quest: currentQuest, source: "lab", timestamp: now)
    do {
      exportURL = try EventExporter.write(
        records: fetchEvents(ascending: true),
        catalogVersion: catalogVersion,
        now: now
      )
      exportError = nil
    } catch {
      exportURL = nil
      exportError = error.localizedDescription
      diagnostics.append("事件导出失败：\(error.localizedDescription)")
    }
  }

  private func startNewSession(now: Date) {
    snapshot = QuestSessionSnapshot(sessionID: UUID())
    selectedState = nil
    activeContexts = snapshot.activeContexts
    currentQuest = nil
    persistSnapshot()
    appendEvent(.sessionStarted, source: "session_default", timestamp: now)
    serveRecommended(source: "session_default")
  }

  private func serveRecommended(
    source: String,
    adjustment: SkipReason? = nil
  ) {
    guard let recommendationEngine, let recommendationConfiguration else { return }
    var context = makeRecommendationContext(
      cooldownDays: recommendationConfiguration.guardrails.sameSeedCooldownDays
    )
    apply(adjustment: adjustment, to: &context)

    guard let result = recommendationEngine.recommend(from: quests, context: context) else {
      diagnostics.append("推荐失败：没有符合当前过滤条件的 Quest")
      return
    }
    let serendipity = result.usedSerendipity ? " · controlled serendipity" : ""
    serve(
      result.quest,
      source: source,
      scoreSummary: String(
        format: "%.1f · %@%@", result.totalScore, result.scoreSummary, serendipity)
    )
  }

  private func serve(
    _ quest: QuestDefinition,
    source: String,
    scoreSummary: String
  ) {
    currentQuest = quest
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
      selectedState: selectedState
    )
  }

  private func makeRecommendationContext(cooldownDays: Int) -> RecommendationContext {
    let cutoff = Date().addingTimeInterval(-Double(cooldownDays) * 86_400)
    let served = fetchEvents(ascending: false)
      .filter { $0.type == QuestEventType.questServed.rawValue }
    let recentForDiversity = Array(served.prefix(7).reversed())
    let allowedMovement: Set<String> =
      selectedState == .move
      ? ["Stay Here", "Few Steps", "Under 50m"]
      : ["Stay Here", "Few Steps"]

    return RecommendationContext(
      selectedState: selectedState,
      allowedMovement: allowedMovement,
      activeContexts: Set(activeContexts),
      recentSeedIDs: Set(served.filter { $0.timestamp >= cutoff }.compactMap(\.seedID)),
      recentWorlds: recentForDiversity.compactMap(\.world),
      recentCanonicalLenses: recentForDiversity.compactMap(\.canonicalLens),
      recentFindHeavy: recentForDiversity.map { event in
        guard let seedID = event.seedID else { return false }
        return catalog?.quest(id: seedID)?.isFindHeavy ?? false
      },
      randomSeed: UInt64.random(in: UInt64.min...UInt64.max)
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

  @discardableResult
  private func commitPendingSkip(reason: SkipReason?) -> Bool {
    guard let quest = pendingSkipQuest else { return false }
    pendingSkipQuest = nil
    snapshot.consecutiveSkips += 1
    snapshot.currentServeSkipped = true
    persistSnapshot()
    appendEvent(
      .questSkipped,
      quest: quest,
      source: "reason_prompt",
      selectedState: selectedState,
      skipReason: reason
    )
    return true
  }

  private func hasFeedbackForCurrentQuest() -> Bool {
    guard let currentQuest, let sessionID = snapshot.sessionID else { return false }
    return recentEvents.contains {
      $0.type == QuestEventType.attentionShiftFeedback.rawValue
        && $0.seedID == currentQuest.id
        && $0.sessionID == sessionID
    }
  }

  private func appendEvent(
    _ type: QuestEventType,
    quest: QuestDefinition? = nil,
    source: String? = nil,
    selectedState: ExplorerState? = nil,
    skipReason: SkipReason? = nil,
    feedbackValue: FeedbackValue? = nil,
    timestamp: Date = Date()
  ) {
    let record = QuestEventRecord(
      timestamp: timestamp,
      type: type,
      sessionID: snapshot.sessionID,
      quest: quest,
      source: source,
      selectedState: selectedState,
      skipReason: skipReason,
      feedbackValue: feedbackValue
    )
    modelContext.insert(record)
    do {
      try modelContext.save()
    } catch {
      diagnostics.append("事件保存失败：\(error.localizedDescription)")
    }
    refreshRecentEvents()
  }

  private func fetchEvents(ascending: Bool) -> [QuestEventRecord] {
    let order: SortOrder = ascending ? .forward : .reverse
    let descriptor = FetchDescriptor<QuestEventRecord>(
      sortBy: [SortDescriptor(\.timestamp, order: order)]
    )
    do {
      return try modelContext.fetch(descriptor)
    } catch {
      diagnostics.append("事件读取失败：\(error.localizedDescription)")
      return []
    }
  }

  private func refreshRecentEvents() {
    recentEvents = Array(fetchEvents(ascending: false).prefix(40))
  }

  private func persistSnapshot() {
    persistence.save(snapshot)
  }
}
