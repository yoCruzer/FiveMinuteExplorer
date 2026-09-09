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

  @Test func catalogContractsAndContextProfiles() throws {
    let quests = try BundledQuestCatalog().quests
    let worlds = Set(WorldPresentation.ordered)
    let movements: Set<String> = ["Stay Here", "Few Steps", "Under 50m", "Short Walk"]
    let ranks: Set<String> = ["Featured", "Recommended", "Niche", "Deep Cut", "Experimental"]
    let surfaces: Set<String> = [
      "General default", "Contextual default", "Browse first", "Experimental only",
    ]
    for quest in quests {
      #expect(!quest.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      #expect(!quest.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      #expect(worlds.contains(quest.world) && movements.contains(quest.movement))
      #expect(ranks.contains(quest.rank) && surfaces.contains(quest.defaultSurface))
    }
    let visible = QuestMatchingPolicy.libraryQuests(quests)
    #expect(
      visible.allSatisfy { $0.rank != "Experimental" && $0.defaultSurface != "Experimental only" })
    for profile in ContextProfile.allCases {
      #expect(visible.contains(where: profile.matches), "Empty profile \(profile.rawValue)")
    }
    let food = quests.filter { $0.context.contains("Waiting for Food") }
    #expect(!food.isEmpty && food.allSatisfy(ContextProfile.waiting.matches))
    let transit = quests.filter {
      $0.context.contains("Station") || $0.context.contains("Airport")
        || $0.environment.contains("Transit")
    }
    #expect(!transit.isEmpty && transit.allSatisfy(ContextProfile.transit.matches))
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
