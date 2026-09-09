import Foundation
import SwiftData
import Testing

@testable import FiveMinuteExplorer

@MainActor
struct ExplorerStoreTests {
  private let now = Date(timeIntervalSince1970: 2_000_000)

  private func fixture() throws -> (ExplorerStore, ModelContext, SessionPersistence) {
    let container = try ModelContainer(
      for: QuestEventRecord.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    let defaults = try #require(UserDefaults(suiteName: "StoreTests-\(UUID())"))
    let persistence = SessionPersistence(defaults: defaults)
    persistence.hasSeenIntro = true
    let store = ExplorerStore(
      modelContext: context, persistence: persistence,
      clock: { now }, randomSeed: { 9 })
    store.startIfNeeded(now: now)
    return (store, context, persistence)
  }

  private func events(_ context: ModelContext, _ type: QuestEventType) throws -> [QuestEventRecord]
  {
    try context.fetch(FetchDescriptor<QuestEventRecord>()).filter { $0.type == type.rawValue }
  }

  @Test func warmResumeDoesNotServeAgain() throws {
    let (store, context, persistence) = try fixture()
    let quest = store.currentQuest
    let session = persistence.load()?.sessionID
    store.appDidEnterBackground(now: now)
    store.appDidBecomeActive(now: now.addingTimeInterval(90))
    store.startIfNeeded(now: now.addingTimeInterval(91))
    #expect(store.currentQuest == quest)
    #expect(persistence.load()?.sessionID == session)
    #expect(try events(context, .questServed).count == 1)
    #expect(store.isFeedbackPresented)
  }

  @Test func longResumeKeepsPreviousReflectionIdentity() throws {
    let (store, context, persistence) = try fixture()
    let seed = try #require(store.currentQuest?.id)
    let session = try #require(persistence.load()?.sessionID)
    store.appDidEnterBackground(now: now)
    store.appDidBecomeActive(now: now.addingTimeInterval(1900))
    #expect(persistence.load()?.sessionID != session)
    #expect(store.isFeedbackPresented)
    store.feedbackPromptDidAppear()
    store.feedbackPromptDidAppear()
    store.submitFeedback(.yes)
    let shown = try #require(events(context, .attentionShiftPromptShown).first)
    let answered = try #require(events(context, .attentionShiftFeedback).first)
    #expect(shown.sessionID == session && shown.seedID == seed)
    #expect(answered.sessionID == session && answered.seedID == seed)
    #expect(try events(context, .attentionShiftPromptShown).count == 1)
    #expect(!store.isFeedbackPresented)
  }

  @Test func coldStaleMissingBackgroundStartsNewSession() throws {
    let (_, context, persistence) = try fixture()
    var stale = try #require(persistence.load())
    let oldSession = stale.sessionID
    stale.lastBackgroundedAt = nil
    stale.lastActivityAt = now.addingTimeInterval(-1900)
    stale.selectedState = .listen
    stale.contextProfile = .home
    persistence.save(stale)
    let reopened = ExplorerStore(modelContext: context, persistence: persistence, clock: { now })
    reopened.startIfNeeded(now: now)
    #expect(persistence.load()?.sessionID != oldSession)
    #expect(reopened.selectedState == nil && reopened.contextProfile == nil)
    #expect(try events(context, .questServed).count == 2)
  }

  @Test func nonHomeBackgroundDoesNotOfferReflection() throws {
    for surface in [AppSurface.explore, .lab, .skipHelp, .feedback, .intro] {
      let (store, context, _) = try fixture()
      store.isExplorePresented = surface == .explore
      store.isLabPresented = surface == .lab
      store.isSkipHelpPresented = surface == .skipHelp
      store.isFeedbackPresented = surface == .feedback
      if surface == .intro { store.resetIntro() }
      store.appDidEnterBackground(now: now)
      store.isFeedbackPresented = false
      store.appDidBecomeActive(now: now.addingTimeInterval(90))
      #expect(!store.isFeedbackPresented)
      #expect(try events(context, .appBackgrounded).last?.surface == surface.rawValue)
    }
  }

  @Test func thirdSkipIsDurableBeforeReasonAndDismissDoesNotCountTwice() throws {
    let (store, context, persistence) = try fixture()
    store.selectState(.listen)
    store.selectContext(.home)
    store.skipCurrent()
    store.skipCurrent()
    let rejected = store.currentQuest
    store.skipCurrent()
    #expect(store.currentQuest == nil)
    #expect(store.isSkipHelpPresented)
    #expect(persistence.load()?.activeQuestID == nil)
    #expect(persistence.load()?.consecutiveSkips == 3)
    let skips = try events(context, .questSkipped)
    #expect(skips.count == 3)
    #expect(skips.allSatisfy { $0.selectedState == "Listen" && $0.contextProfile == "home" })
    store.skipHelpDidDismiss()
    store.skipHelpDidDismiss()
    #expect(store.currentQuest != rejected)
    #expect(store.selectedState == .doNothing)
    #expect(try events(context, .questSkipped).count == 3)
  }

  @Test func libraryCommitPreservesIntentAndServesExactlyOnce() throws {
    let (store, context, persistence) = try fixture()
    let listen = try #require(
      store.quests.first { QuestMatchingPolicy.stateFit($0, state: .listen) == 1 })
    store.selectFromLibrary(listen, source: "explore_state", sourceDetail: "listen")
    #expect(store.selectedState == .listen)
    #expect(try events(context, .questServed).count == 2)
    for profile in [ContextProfile.home, .transit] {
      let quest = try #require(store.quests.first { profile.matches($0) })
      let before = try events(context, .questServed).count
      store.selectFromLibrary(quest, source: "explore_context", sourceDetail: profile.rawValue)
      #expect(store.contextProfile == profile)
      #expect(store.currentQuest == quest)
      #expect(try events(context, .questServed).count == before + 1)
      store.skipCurrent()
      #expect(store.contextProfile == profile && store.selectedState == .listen)
      #expect(persistence.load()?.contextProfile == profile)
    }
  }

  @Test func failedExportDoesNotLogSuccess() throws {
    let (store, context, _) = try fixture()
    store.exportEvents(directory: URL(fileURLWithPath: "/missing-\(UUID())/directory"))
    #expect(store.exportError != nil)
    #expect(try events(context, .eventLogExported).isEmpty)
  }

  @Test func everySkipReasonHasImmediateEffect() throws {
    for reason in SkipReason.allCases {
      let (store, context, _) = try fixture()
      store.skipCurrent()
      store.skipCurrent()
      let rejected = try #require(store.currentQuest)
      store.skipCurrent()
      let before = try events(context, .questServed).count
      store.resolvePendingSkip(reason: reason)
      store.skipHelpDidDismiss()
      let replacement = try #require(store.currentQuest)
      #expect(replacement.id != rejected.id)
      #expect(try events(context, .questServed).count == before + 1)
      #expect(try events(context, .questSkipped).count == 3)
      #expect(try events(context, .skipReasonSelected).count == 1)
      switch reason {
      case .movementMismatch: #expect(replacement.movement == "Stay Here")
      case .contextMismatch:
        #expect(
          replacement.defaultSurface == "General default"
            && replacement.context.contains("Anywhere"))
      case .tooMuchEffort: #expect(["Very Low", "Low"].contains(replacement.cognitiveLoad))
      case .tasteMismatch: #expect(replacement.world != rejected.world)
      case .notNow: #expect(store.selectedState == .doNothing)
      }
    }
  }

  @Test func choosingSameStateFromSkipStillServesOnce() throws {
    let (store, context, _) = try fixture()
    store.selectState(.listen)
    for _ in 0..<3 { store.skipCurrent() }
    let before = try events(context, .questServed).count
    store.chooseStateFromSkip(.listen)
    store.skipHelpDidDismiss()
    #expect(try events(context, .questServed).count == before + 1)
  }

  @Test func storeRecoversWhenAllSeedsAreCoolingDown() throws {
    let (store, context, _) = try fixture()
    for quest in store.quests {
      context.insert(
        QuestEventRecord(timestamp: now.addingTimeInterval(-1), type: .questServed, quest: quest))
    }
    try context.save()
    store.skipCurrent()
    #expect(store.currentQuest != nil && !store.recommendationUnavailable)
    #expect(
      store.recentEvents.contains { $0.type == "quest_served" && ($0.fallbackLevel ?? 0) > 0 })
  }

  @Test func oldFeedbackOutsideRecentCacheIsStillHandled() throws {
    let (store, context, persistence) = try fixture()
    let quest = try #require(store.currentQuest)
    let session = try #require(persistence.load()?.sessionID)
    context.insert(
      QuestEventRecord(
        timestamp: now.addingTimeInterval(-100),
        type: .attentionShiftFeedback, sessionID: session, quest: quest, feedbackValue: .yes))
    for _ in 0..<45 { context.insert(QuestEventRecord(timestamp: now, type: .appOpened)) }
    try context.save()
    store.appDidEnterBackground(now: now)
    #expect(!store.recentEvents.contains { $0.type == "attention_shift_feedback" })
    store.appDidBecomeActive(now: now.addingTimeInterval(90))
    #expect(!store.isFeedbackPresented)
  }

  @Test func legacySnapshotWithoutTimingExpires() throws {
    let (_, context, persistence) = try fixture()
    var snapshot = try #require(persistence.load())
    let old = snapshot.sessionID
    snapshot.lastActivityAt = nil
    snapshot.lastBackgroundedAt = nil
    persistence.save(snapshot)
    let reopened = ExplorerStore(modelContext: context, persistence: persistence, clock: { now })
    reopened.startIfNeeded(now: now)
    #expect(persistence.load()?.sessionID != old)
  }

  @Test func coldLongReturnRetainsReflectionAndThirdSkipSurvivesRelaunch() throws {
    let (store, context, persistence) = try fixture()
    let old = persistence.load()?.sessionID
    let seed = store.currentQuest?.id
    store.appDidEnterBackground(now: now)
    let reopened = ExplorerStore(
      modelContext: context, persistence: persistence, clock: { now.addingTimeInterval(2000) })
    reopened.startIfNeeded(now: now.addingTimeInterval(2000))
    reopened.feedbackPromptDidAppear()
    reopened.dismissFeedback()
    #expect(
      try events(context, .attentionShiftDismissed).contains {
        $0.sessionID == old && $0.seedID == seed
      })
    for _ in 0..<3 { reopened.skipCurrent() }
    let rejected = try events(context, .questSkipped).map(\.seedID)
    let cold = ExplorerStore(
      modelContext: context, persistence: persistence, clock: { now.addingTimeInterval(2010) })
    cold.startIfNeeded(now: now.addingTimeInterval(2010))
    #expect(try events(context, .questSkipped).count == 3)
    #expect(cold.selectedState == .doNothing)
    #expect(!rejected.contains(cold.currentQuest?.id))
  }

  @Test func worldSelectionDoesNotInventPreferences() throws {
    let (store, context, _) = try fixture()
    let quest = try #require(store.quests.first { $0.world == "Human Traces" })
    store.selectFromLibrary(quest, source: "explore_world", sourceDetail: "Human Traces")
    #expect(store.selectedState == nil && store.contextProfile == nil)
    #expect(try events(context, .questServed).count == 2)
  }

  @Test func exportRetainsIdentitySourcesAndAttentionMetrics() throws {
    let (store, context, _) = try fixture()
    let quest = try #require(store.currentQuest)
    store.selectFromLibrary(quest, source: "explore_state", sourceDetail: "listen")
    store.selectFromLibrary(quest, source: "explore_context", sourceDetail: "home")
    store.selectFromLibrary(quest, source: "explore_world", sourceDetail: "Human Traces")
    store.appDidEnterBackground(now: now)
    store.appDidBecomeActive(now: now.addingTimeInterval(90))
    #expect(try events(context, .attentionShiftPromptShown).isEmpty)
    store.feedbackPromptDidAppear()
    store.submitFeedback(.notTried)
    store.exportEvents(now: now)
    let url = try #require(store.exportURL)
    defer { try? FileManager.default.removeItem(at: url) }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let envelope = try decoder.decode(QuestEventExportEnvelope.self, from: Data(contentsOf: url))
    #expect(envelope.schemaVersion == "v0.2")
    #expect(envelope.catalogVersion == "v1" && envelope.recommendationVersion == "v1")
    #expect(
      envelope.appVersion == Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String)
    #expect(
      envelope.buildNumber == Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    )
    for detail in ["listen", "home", "Human Traces"] {
      #expect(
        envelope.events.contains {
          $0.type == "quest_selected_from_library" && $0.sourceDetail == detail
        })
      #expect(envelope.events.contains { $0.type == "quest_served" && $0.sourceDetail == detail })
    }
    #expect(envelope.events.contains { $0.type == "attention_shift_prompt_shown" })
    #expect(
      envelope.events.contains {
        $0.type == "attention_shift_feedback" && $0.feedbackValue == "not_tried"
      })
    #expect(
      envelope.events.contains {
        $0.type == "quest_served" && $0.recommendationScore != nil
          && $0.usedSerendipity != nil && $0.fallbackLevel != nil
          && $0.recommendationVersion == "v1"
      })
    #expect(try events(context, .eventLogExported).count == 1)
    // The export-success event is appended after the successful write, not pre-inserted in its own file.
    #expect(!envelope.events.contains { $0.type == "event_log_exported" })
  }
}
