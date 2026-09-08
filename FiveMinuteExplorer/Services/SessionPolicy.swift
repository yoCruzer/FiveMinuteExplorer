import Foundation

enum SessionPolicy {
  static let inactivityTimeout: TimeInterval = 30 * 60
  static let feedbackDelay: TimeInterval = 60

  static func shouldStartNewSession(
    activeQuestID: Int?,
    lastBackgroundedAt: Date?,
    now: Date
  ) -> Bool {
    guard activeQuestID != nil else { return true }
    guard let lastBackgroundedAt else { return false }
    return now.timeIntervalSince(lastBackgroundedAt) >= inactivityTimeout
  }

  static func shouldOfferFeedback(
    backgroundedAt: Date?,
    now: Date,
    hasActiveQuest: Bool,
    wasSkipped: Bool,
    alreadyHandled: Bool
  ) -> Bool {
    guard let backgroundedAt, hasActiveQuest, !wasSkipped, !alreadyHandled else {
      return false
    }
    return now.timeIntervalSince(backgroundedAt) >= feedbackDelay
  }
}

enum SkipPolicyAction: Equatable {
  case replaceImmediately
  case askForReason
}

enum SkipPolicy {
  static let immediateReplacementLimit = 2

  static func action(afterConsecutiveSkipCount count: Int) -> SkipPolicyAction {
    count <= immediateReplacementLimit ? .replaceImmediately : .askForReason
  }
}

struct QuestSessionSnapshot: Codable, Equatable {
  var sessionID: UUID?
  var activeQuestID: Int?
  var selectedState: ExplorerState?
  var consecutiveSkips = 0
  var lastBackgroundedAt: Date?
  var currentServeSkipped = false
  var feedbackPromptDismissedSeedID: Int?
  var activeContexts = ["Anywhere"]
}

struct SessionPersistence {
  private static let snapshotKey = "quest-session-v0"
  private static let introKey = "has-seen-intro-v0"

  let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var hasSeenIntro: Bool {
    get { defaults.bool(forKey: Self.introKey) }
    nonmutating set { defaults.set(newValue, forKey: Self.introKey) }
  }

  func load() -> QuestSessionSnapshot? {
    guard let data = defaults.data(forKey: Self.snapshotKey) else { return nil }
    return try? JSONDecoder().decode(QuestSessionSnapshot.self, from: data)
  }

  func save(_ snapshot: QuestSessionSnapshot) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    defaults.set(data, forKey: Self.snapshotKey)
  }

  func clearSession() {
    defaults.removeObject(forKey: Self.snapshotKey)
  }
}
