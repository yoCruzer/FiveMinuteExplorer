import Foundation

struct QuestDefinition: Codable, Identifiable, Hashable, Sendable {
  let id: Int
  let originalSeed: String
  let title: String
  let text: String
  let world: String
  let rawLens: [String]
  let canonicalLens: String
  let actions: [String]
  let moods: [String]
  let time: String
  let energy: String
  let cognitiveLoad: String
  let movement: String
  let environment: [String]
  let context: [String]
  let depth: String
  let rank: String
  let defaultSurface: String
  let safety: [String]
  let whyKeep: String
  let catalogStatus: String

  var isFindHeavy: Bool { actions.contains("Find") }

  var localizedTime: String {
    time.replacingOccurrences(of: "min", with: "分钟")
  }

  var localizedMovement: String {
    switch movement {
    case "Stay Here": "原地"
    case "Few Steps": "走几步"
    case "Under 50m": "50 米内"
    default: movement
    }
  }
}

struct QuestCatalogEnvelope: Codable, Sendable {
  let catalogVersion: String
  let questCount: Int
  let quests: [QuestDefinition]
}

enum ExplorerState: String, CaseIterable, Codable, Identifiable, Sendable {
  case easy = "Easy"
  case calm = "Calm"
  case think = "Think"
  case move = "Move"
  case listen = "Listen"
  case doNothing = "Do nothing"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .easy: "轻松一点"
    case .calm: "安静一点"
    case .think: "想想为什么"
    case .move: "动一下"
    case .listen: "听一听"
    case .doNothing: "什么也不做"
    }
  }
}

enum SkipReason: String, CaseIterable, Identifiable, Sendable {
  case contextMismatch = "context_mismatch"
  case movementMismatch = "movement_mismatch"
  case tooMuchEffort = "too_much_effort"
  case tasteMismatch = "taste_mismatch"
  case notNow = "not_now"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .contextMismatch: "这里做不了"
    case .movementMismatch: "不想动"
    case .tooMuchEffort: "太费脑"
    case .tasteMismatch: "不喜欢这类"
    case .notNow: "只是现在不想做"
    }
  }
}

enum FeedbackValue: String, Sendable {
  case yes
  case no
  case notTried = "not_tried"

  var title: String {
    switch self {
    case .yes: "有"
    case .no: "没有"
    case .notTried: "没做"
    }
  }
}

enum WorldPresentation {
  static let ordered = [
    "Look Closer",
    "Hidden Design",
    "Human Traces",
    "Patterns & Exceptions",
    "Space & Boundaries",
    "Nature Around You",
    "Listen & Sense",
    "Move a Little",
    "Imagine & Create",
    "Pause",
  ]

  static func title(for world: String) -> String {
    switch world {
    case "Look Closer": "换个角度看"
    case "Hidden Design": "隐藏的设计"
    case "Human Traces": "人的痕迹"
    case "Patterns & Exceptions": "规律与例外"
    case "Space & Boundaries": "空间与边界"
    case "Nature Around You": "身边的自然"
    case "Listen & Sense": "听见与感受"
    case "Move a Little": "动一下"
    case "Imagine & Create": "想象与创造"
    case "Pause": "停一下"
    default: world
    }
  }
}
