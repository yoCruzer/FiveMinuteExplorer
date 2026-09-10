import Foundation
import Testing

@testable import FiveMinuteExplorer

@MainActor
struct CatalogTests {
  @Test func explicitProfilesPreferRealExactContent() throws {
    let quests = try BundledQuestCatalog().quests
    let engine = RecommendationEngineV1(configuration: try RecommendationConfiguration.bundled())
    // Seed 9 takes the normal path; assert that fact alongside the recommendation.
    for profile in ContextProfile.allCases {
      for state: ExplorerState? in [nil, .listen, .think] {
        let context = RecommendationContext(
          selectedState: state, activeContexts: profile.confirmedContexts,
          contextProfile: profile, randomSeed: 9)
        let exact = quests.filter { profile.matches($0) && engine.passesHardFilters($0, context: context) }
        #expect(!exact.isEmpty, "No hard-eligible exact pool: \(profile)")
        let result = try #require(engine.recommend(from: quests, context: context))
        #expect(!result.usedSerendipity)
        #expect(profile.matches(result.quest), "Generic replacement: \(profile) / \(result.quest.id)")
      }
    }
  }

  @Test func realNightRequiresSessionConfirmation() throws {
    let quests = try BundledQuestCatalog().quests
    let engine = RecommendationEngineV1(configuration: try RecommendationConfiguration.bundled())
    let night = quests.filter { $0.safety.contains("NightSafeOnly") }
    #expect(!night.isEmpty)
    for quest in night {
      #expect(!engine.passesHardFilters(quest, context: RecommendationContext(randomSeed: 9)))
      #expect(!engine.passesHardFilters(quest, context: RecommendationContext(
        activeContexts: ["Night"], contextProfile: .night, randomSeed: 9)))
    }
    let confirmed = RecommendationContext(
      activeContexts: ContextProfile.night.confirmedContexts, contextProfile: .night, randomSeed: 9)
    #expect(night.contains { engine.passesHardFilters($0, context: confirmed) })
    #expect(ContextProfile.night.title == "安全明亮的夜晚")
    #expect(!ContextProfile.night.confirmsPublicSpace)
  }

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
