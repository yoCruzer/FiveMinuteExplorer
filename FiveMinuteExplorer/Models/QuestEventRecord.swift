import Foundation
import SwiftData

enum QuestEventType: String, Codable, Sendable {
  case appOpened = "app_opened"
  case sessionStarted = "session_started"
  case questServed = "quest_served"
  case questSkipped = "quest_skipped"
  case skipReasonSelected = "skip_reason_selected"
  case contextChanged = "context_changed"
  case attentionShiftPromptShown = "attention_shift_prompt_shown"
  case attentionShiftDismissed = "attention_shift_dismissed"
  case questSelectedFromLibrary = "quest_selected_from_library"
  case stateChanged = "state_changed"
  case appBackgrounded = "app_backgrounded"
  case attentionShiftFeedback = "attention_shift_feedback"
  case moreLikeThis = "more_like_this"
  case lessLikeThis = "less_like_this"
  case eventLogExported = "event_log_exported"
}

@Model
final class QuestEventRecord {
  @Attribute(.unique) var id: UUID
  var timestamp: Date
  var type: String
  var sessionID: UUID?
  var seedID: Int?
  var world: String?
  var canonicalLens: String?
  var rank: String?
  var defaultSurface: String?
  var source: String?
  var selectedState: String?
  var skipReason: String?
  var feedbackValue: String?
  var sourceDetail: String?
  var surface: String?
  var contextProfile: String?
  var recommendationVersion: String?
  var recommendationScore: Double?
  var usedSerendipity: Bool?
  var fallbackLevel: Int?

  init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    type: QuestEventType,
    sessionID: UUID? = nil,
    quest: QuestDefinition? = nil,
    source: String? = nil,
    selectedState: ExplorerState? = nil,
    skipReason: SkipReason? = nil,
    feedbackValue: FeedbackValue? = nil
  ) {
    self.id = id
    self.timestamp = timestamp
    self.type = type.rawValue
    self.sessionID = sessionID
    seedID = quest?.id
    world = quest?.world
    canonicalLens = quest?.canonicalLens
    rank = quest?.rank
    defaultSurface = quest?.defaultSurface
    self.source = source
    self.selectedState = selectedState?.rawValue
    self.skipReason = skipReason?.rawValue
    self.feedbackValue = feedbackValue?.rawValue
  }
}

struct QuestEventExport: Codable {
  let id: UUID
  let timestamp: Date
  let type: String
  let sessionID: UUID?
  let seedID: Int?
  let world: String?
  let canonicalLens: String?
  let rank: String?
  let defaultSurface: String?
  let source: String?
  let selectedState: String?
  let skipReason: String?
  let feedbackValue: String?
  let sourceDetail: String?
  let surface: String?
  let contextProfile: String?
  let recommendationVersion: String?
  let recommendationScore: Double?
  let usedSerendipity: Bool?
  let fallbackLevel: Int?

  init(_ record: QuestEventRecord) {
    id = record.id
    timestamp = record.timestamp
    type = record.type
    sessionID = record.sessionID
    seedID = record.seedID
    world = record.world
    canonicalLens = record.canonicalLens
    rank = record.rank
    defaultSurface = record.defaultSurface
    source = record.source
    selectedState = record.selectedState
    skipReason = record.skipReason
    feedbackValue = record.feedbackValue
    sourceDetail = record.sourceDetail
    surface = record.surface
    contextProfile = record.contextProfile
    recommendationVersion = record.recommendationVersion
    recommendationScore = record.recommendationScore
    usedSerendipity = record.usedSerendipity
    fallbackLevel = record.fallbackLevel
  }
}

struct QuestEventExportEnvelope: Codable {
  let schemaVersion: String
  let appVersion: String
  let buildNumber: String
  let catalogVersion: String
  let recommendationVersion: String
  let exportedAt: Date
  let events: [QuestEventExport]
}
