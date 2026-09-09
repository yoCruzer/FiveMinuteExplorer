import Foundation
import Testing

@testable import FiveMinuteExplorer

@MainActor
struct SessionPolicyTests {
  @Test
  func shortReopenKeepsCurrentSession() {
    let backgrounded = Date(timeIntervalSince1970: 1_000)
    let reopened = backgrounded.addingTimeInterval(SessionPolicy.inactivityTimeout - 1)

    #expect(
      !SessionPolicy.shouldStartNewSession(
        activeQuestID: 42,
        lastBackgroundedAt: backgrounded,
        now: reopened
      ))
  }

  @Test
  func longReopenStartsNewSession() {
    let backgrounded = Date(timeIntervalSince1970: 1_000)
    let reopened = backgrounded.addingTimeInterval(SessionPolicy.inactivityTimeout)

    #expect(
      SessionPolicy.shouldStartNewSession(
        activeQuestID: 42,
        lastBackgroundedAt: backgrounded,
        now: reopened
      ))
  }

  @Test
  func feedbackRequiresSixtySecondsAndAnUnskippedQuest() {
    let backgrounded = Date(timeIntervalSince1970: 1_000)
    let reopened = backgrounded.addingTimeInterval(SessionPolicy.feedbackDelay)

    #expect(
      SessionPolicy.shouldOfferFeedback(
        backgroundedAt: backgrounded,
        now: reopened,
        hasActiveQuest: true,
        wasSkipped: false,
        alreadyHandled: false
      ))
    #expect(
      !SessionPolicy.shouldOfferFeedback(
        backgroundedAt: backgrounded,
        now: reopened,
        hasActiveQuest: true,
        wasSkipped: true,
        alreadyHandled: false
      ))
  }

  @Test
  func firstTwoSkipsReplaceAndThirdAsksForReason() {
    #expect(SkipPolicy.action(afterConsecutiveSkipCount: 1, limit: 2) == .replaceImmediately)
    #expect(SkipPolicy.action(afterConsecutiveSkipCount: 2, limit: 2) == .replaceImmediately)
    #expect(SkipPolicy.action(afterConsecutiveSkipCount: 3, limit: 2) == .askForReason)
  }

  @Test
  func currentQuestSessionSnapshotPersists() throws {
    let suiteName = "FiveMinuteExplorerTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let persistence = SessionPersistence(defaults: defaults)
    let expected = QuestSessionSnapshot(
      sessionID: UUID(),
      activeQuestID: 128,
      selectedState: .listen,
      consecutiveSkips: 1,
      lastBackgroundedAt: Date(timeIntervalSince1970: 2_000),
      currentServeSkipped: false,
      feedbackPromptDismissedSeedID: nil,
      activeContexts: ["Anywhere"]
    )

    persistence.save(expected)

    #expect(persistence.load() == expected)
  }
}
