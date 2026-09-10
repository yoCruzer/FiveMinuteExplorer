import Foundation

enum ContextProfile: String, Codable, CaseIterable, Identifiable {
  case waiting, home
  case workSchool = "work_school"
  case cafeRestaurant = "cafe_restaurant"
  case transit, travel, night
  case familiarPlace = "familiar_place"
  case natureNearby = "nature_nearby"

  var id: String { rawValue }
  var title: String {
    switch self {
    case .waiting: "等待时"
    case .home: "在家"
    case .workSchool: "工作 / 学校"
    case .cafeRestaurant: "咖啡馆 / 餐厅"
    case .transit: "车站 / 机场"
    case .travel: "旅行中"
    case .night: "安全明亮的夜晚"
    case .familiarPlace: "熟悉的地方"
    case .natureNearby: "附近有自然"
    }
  }
  var contexts: Set<String> {
    switch self {
    case .waiting: ["Waiting", "Waiting for Food"]
    case .home: ["Home"]
    case .workSchool: ["Work", "School"]
    case .cafeRestaurant: ["Cafe", "Restaurant", "Waiting for Food"]
    case .transit: ["Station", "Airport"]
    case .travel: ["Travel", "Hotel"]
    case .night: ["Night"]
    case .familiarPlace: ["Familiar Place"]
    case .natureNearby: ["Nature Nearby"]
    }
  }
  var environments: Set<String> {
    switch self {
    case .home: ["Home"]
    case .familiarPlace: ["Familiar Place"]
    case .workSchool: ["WorkSchool"]
    case .transit: ["Transit"]
    case .natureNearby: ["Nature Nearby"]
    default: []
    }
  }
  var confirmsPublicSpace: Bool { self == .transit || self == .cafeRestaurant }
  // Confirmation is supplied only when the user selects the profile, not as a taxonomy alias.
  var confirmedContexts: Set<String> {
    self == .night ? contexts.union(["Safe Lit Space"]) : contexts
  }
  func matches(_ quest: QuestDefinition) -> Bool {
    !contexts.isDisjoint(with: quest.context) || !environments.isDisjoint(with: quest.environment)
  }
}

enum QuestMatchingPolicy {
  enum ContextCompatibility: Int {
    case incompatible, universal, confirmedPublicSpace, exact

    var fit: Double {
      switch self {
      case .incompatible: 0
      case .universal: 0.2
      case .confirmedPublicSpace: 0.8
      case .exact: 1
      }
    }
  }

  static func contextCompatibility(
    _ quest: QuestDefinition, profile: ContextProfile
  ) -> ContextCompatibility {
    if profile.matches(quest) { return .exact }
    let contexts = Set(quest.context).subtracting(["Anywhere"])
    let specificEnvironments: Set<String> = [
      "Home", "WorkSchool", "Transit", "Familiar Place", "Nature Nearby",
    ]
    guard specificEnvironments.isDisjoint(with: quest.environment) else {
      return .incompatible
    }
    let publicContexts: Set<String> = ["Public Space", "Public Safe Space", "Safe Public Space"]
    if profile.confirmsPublicSpace,
      (!contexts.isEmpty && contexts.isSubset(of: publicContexts)
        || contexts.isEmpty && quest.safety.contains("PublicSpaceOnly"))
    {
      return .confirmedPublicSpace
    }
    return contexts.isEmpty && quest.context.contains("Anywhere")
      && !quest.safety.contains("PublicSpaceOnly") ? .universal : .incompatible
  }

  static func stateFit(_ quest: QuestDefinition, state: ExplorerState?) -> Double {
    guard let state else { return 0.5 }
    switch state {
    case .easy:
      return max(
        quest.moods.contains("Easy") ? 1 : 0,
        ["Very Low", "Low"].contains(quest.cognitiveLoad) ? 0.75 : 0.2)
    case .calm: return quest.moods.contains("Calm") || quest.world == "Pause" ? 1 : 0.25
    case .think: return quest.moods.contains("Think") || quest.depth == "Deep" ? 1 : 0.2
    case .move:
      return quest.world == "Move a Little" || ["Under 50m", "Short Walk"].contains(quest.movement)
        ? 1 : 0.2
    case .listen:
      return quest.world == "Listen & Sense" || quest.actions.contains("Listen") ? 1 : 0.15
    case .doNothing: return quest.world == "Pause" || quest.actions.contains("Pause") ? 1 : 0.1
    }
  }

  static func libraryQuests(_ quests: [QuestDefinition]) -> [QuestDefinition] {
    let surface = ["General default": 0, "Contextual default": 1, "Browse first": 2]
    let rank = ["Featured": 0, "Recommended": 1, "Niche": 2, "Deep Cut": 3]
    return quests.filter {
      $0.catalogStatus == "Cataloged" && $0.rank != "Hidden" && $0.rank != "Experimental"
        && $0.defaultSurface != "Experimental only"
    }.sorted {
      (surface[$0.defaultSurface, default: 9], rank[$0.rank, default: 9], $0.id)
        < (surface[$1.defaultSurface, default: 9], rank[$1.rank, default: 9], $1.id)
    }
  }
}

extension ExplorerState {
  var sourceDetail: String {
    self == .doNothing ? "do_nothing" : rawValue.lowercased()
  }
}
