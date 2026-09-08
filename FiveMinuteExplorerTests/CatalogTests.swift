import Foundation
import Testing

@testable import FiveMinuteExplorer

@MainActor
struct CatalogTests {
  @Test
  func bundledCatalogLoadsAllUniqueV1Quests() throws {
    let catalog = try BundledQuestCatalog()

    #expect(catalog.catalogVersion == "v1")
    #expect(catalog.quests.count == 580)
    #expect(Set(catalog.quests.map(\.id)).count == 580)
    #expect(catalog.quest(id: 1)?.title == "最抢眼的颜色")
    #expect(catalog.quest(id: 580) != nil)
  }

  @Test
  func bundledRecommendationConfigurationIsV1() throws {
    let configuration = try RecommendationConfiguration.bundled()

    #expect(configuration.version == "v1")
    #expect(configuration.guardrails.maxDefaultRerollsBeforeStatePrompt == 2)
    #expect(configuration.guardrails.canonicalLensCooldownServes == 3)
  }

  @Test
  func bundledCatalogCanRecommendForEveryHomeState() throws {
    let catalog = try BundledQuestCatalog()
    let configuration = try RecommendationConfiguration.bundled()
    let engine = RecommendationEngineV1(configuration: configuration)

    for state in ExplorerState.allCases {
      let result = engine.recommend(
        from: catalog.quests,
        context: RecommendationContext(selectedState: state, randomSeed: 17)
      )
      #expect(result != nil, "No recommendation for \(state.rawValue)")
    }
  }
}
