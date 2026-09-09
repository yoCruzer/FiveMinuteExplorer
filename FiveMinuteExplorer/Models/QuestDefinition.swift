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

  var requirementLabels: [String] {
    let labels = [
      "DaylightOnly": "仅限白天", "NightSafeOnly": "仅限安全明亮的夜间环境",
      "CompanionOnly": "需要同伴", "PublicSpaceOnly": "仅限公共空间",
      "OptionalCamera": "可选拍照", "OptionalText": "可选文字记录",
      "OptionalLookup": "可选查询", "NoPhoneDrawing": "需要纸笔",
      "NaturalInteractionOnly": "仅限自然互动", "ExitAfterShare": "分享后收起手机",
    ]
    var result = safety.compactMap { labels[$0] }
    if context.contains("Safe Walking Area") { result.append("需要安全步行区域") }
    if defaultSurface == "Contextual default" || defaultSurface == "Browse first" {
      let names = [
        "Home": "家中", "Work": "工作场所", "School": "学校", "Station": "车站",
        "Airport": "机场", "Cafe": "咖啡馆", "Restaurant": "餐厅", "Waiting": "等待时",
        "Waiting for Food": "等餐时", "Travel": "旅行中", "Hotel": "酒店", "Night": "夜晚",
        "Nature Nearby": "附近有自然", "Familiar Place": "熟悉的地方", "Daylight": "白天",
        "Public Space": "公共空间", "Safe Walking Area": "安全步行区域",
      ]
      let contexts = context.filter { $0 != "Anywhere" }.map { names[$0] ?? $0 }
      if !contexts.isEmpty { result.append("适用情境：" + contexts.joined(separator: " / ")) }
    }
    return result
  }

  var localizedMovement: String {
    switch movement {
    case "Stay Here": "原地"
    case "Few Steps": "走几步"
    case "Under 50m": "50 米内"
    case "Short Walk": "散步一小段"
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
