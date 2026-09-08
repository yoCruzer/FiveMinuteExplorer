import Foundation

protocol QuestCatalogRepository {
  var catalogVersion: String { get }
  var quests: [QuestDefinition] { get }
  func quest(id: Int) -> QuestDefinition?
}

enum QuestCatalogError: LocalizedError {
  case resourceMissing(String)
  case unsupportedVersion(String)
  case invalidCount(declared: Int, actual: Int)
  case duplicateSeedIDs

  var errorDescription: String? {
    switch self {
    case .resourceMissing(let name): "找不到目录资源：\(name)"
    case .unsupportedVersion(let version): "不支持的目录版本：\(version)"
    case .invalidCount(let declared, let actual): "目录数量不一致：声明 \(declared)，实际 \(actual)"
    case .duplicateSeedIDs: "目录包含重复的 Seed ID"
    }
  }
}

struct BundledQuestCatalog: QuestCatalogRepository {
  static let expectedCatalogVersion = "v1"
  static let expectedQuestCount = 580

  let catalogVersion: String
  let quests: [QuestDefinition]
  private let questsByID: [Int: QuestDefinition]

  init(bundle: Bundle = .main) throws {
    guard let url = bundle.url(forResource: "quests_v1", withExtension: "json") else {
      throw QuestCatalogError.resourceMissing("quests_v1.json")
    }
    try self.init(data: Data(contentsOf: url))
  }

  init(data: Data) throws {
    let envelope = try JSONDecoder().decode(QuestCatalogEnvelope.self, from: data)
    guard envelope.catalogVersion == Self.expectedCatalogVersion else {
      throw QuestCatalogError.unsupportedVersion(envelope.catalogVersion)
    }
    guard envelope.questCount == Self.expectedQuestCount,
      envelope.quests.count == Self.expectedQuestCount
    else {
      throw QuestCatalogError.invalidCount(
        declared: envelope.questCount,
        actual: envelope.quests.count
      )
    }

    let ids = envelope.quests.map(\.id)
    guard Set(ids).count == Self.expectedQuestCount else {
      throw QuestCatalogError.duplicateSeedIDs
    }

    catalogVersion = envelope.catalogVersion
    quests = envelope.quests
    questsByID = Dictionary(uniqueKeysWithValues: quests.map { ($0.id, $0) })
  }

  func quest(id: Int) -> QuestDefinition? {
    questsByID[id]
  }
}

struct RecommendationConfiguration: Codable, Sendable {
  struct Weights: Codable, Sendable {
    let stateFit: Double
    let editorialPriority: Double
    let personalTaste: Double
    let novelty: Double
    let diversityCorrection: Double
    let contextConfidence: Double
  }

  struct Guardrails: Codable, Sendable {
    let serendipityRate: Double
    let sameSeedCooldownDays: Int
    let canonicalLensCooldownServes: Int
    let maxSameWorldConsecutive: Int
    let minDistinctWorldsPer7Serves: Int
    let maxFindHeavyConsecutive: Int
    let targetNonVisualRate: Double
    let pauseBaseRateRange: [Double]
    let maxDefaultRerollsBeforeStatePrompt: Int
  }

  let version: String
  let weights: Weights
  let worldBaseExposure: [String: Double]
  let guardrails: Guardrails

  static func bundled(bundle: Bundle = .main) throws -> RecommendationConfiguration {
    guard let url = bundle.url(forResource: "recommendation_v1", withExtension: "json") else {
      throw QuestCatalogError.resourceMissing("recommendation_v1.json")
    }
    let configuration = try JSONDecoder().decode(
      RecommendationConfiguration.self,
      from: Data(contentsOf: url)
    )
    guard configuration.version == "v1" else {
      throw QuestCatalogError.unsupportedVersion(configuration.version)
    }
    return configuration
  }
}
