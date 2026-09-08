import Foundation

struct RecommendationContext: Sendable {
  var selectedState: ExplorerState?
  var allowedMovement: Set<String> = ["Stay Here", "Few Steps"]
  var activeContexts: Set<String> = ["Anywhere"]
  var recentSeedIDs: Set<Int> = []
  var recentWorlds: [String] = []
  var recentCanonicalLenses: [String] = []
  var recentFindHeavy: [Bool] = []
  var avoidedWorlds: Set<String> = []
  var avoidContextSpecific = false
  var maximumCognitiveLoad: String?
  var randomSeed: UInt64
}

struct RecommendationResult: Sendable {
  let quest: QuestDefinition
  let totalScore: Double
  let scoreSummary: String
  let usedSerendipity: Bool
}

protocol QuestRecommending {
  func recommend(
    from quests: [QuestDefinition],
    context: RecommendationContext
  ) -> RecommendationResult?
}

struct RecommendationEngineV1: QuestRecommending {
  let configuration: RecommendationConfiguration

  func recommend(
    from quests: [QuestDefinition],
    context: RecommendationContext
  ) -> RecommendationResult? {
    var candidates = quests.filter { passesHardFilters($0, context: context) }
    let lensCooldown = Set(
      context.recentCanonicalLenses.suffix(configuration.guardrails.canonicalLensCooldownServes)
    )
    candidates.removeAll {
      context.recentSeedIDs.contains($0.id) || lensCooldown.contains($0.canonicalLens)
    }

    if let repeatedWorld = repeatedRecentWorld(in: context) {
      let alternatives = candidates.filter { $0.world != repeatedWorld }
      if !alternatives.isEmpty { candidates = alternatives }
    }

    if context.recentFindHeavy
      .suffix(configuration.guardrails.maxFindHeavyConsecutive)
      .allSatisfy({ $0 }),
      context.recentFindHeavy.count >= configuration.guardrails.maxFindHeavyConsecutive,
      !context.recentFindHeavy.isEmpty
    {
      let alternatives = candidates.filter { !$0.isFindHeavy }
      if !alternatives.isEmpty { candidates = alternatives }
    }

    let ranked = candidates.map { quest -> ScoredCandidate in
      let components = scoreComponents(for: quest, context: context)
      return ScoredCandidate(quest: quest, components: components)
    }
    .sorted {
      if $0.total == $1.total { return $0.quest.id < $1.quest.id }
      return $0.total > $1.total
    }

    guard !ranked.isEmpty else { return nil }

    var generator = SeededRandomNumberGenerator(seed: context.randomSeed)
    let usedSerendipity = generator.nextUnitInterval() < configuration.guardrails.serendipityRate
    let poolCount = min(usedSerendipity ? 12 : 1, ranked.count)
    let chosenIndex = Int(generator.next() % UInt64(poolCount))
    let chosen = ranked[chosenIndex]

    return RecommendationResult(
      quest: chosen.quest,
      totalScore: chosen.total,
      scoreSummary: chosen.summary,
      usedSerendipity: usedSerendipity
    )
  }

  private func passesHardFilters(
    _ quest: QuestDefinition,
    context: RecommendationContext
  ) -> Bool {
    guard quest.catalogStatus == "Cataloged",
      quest.rank != "Experimental",
      quest.rank != "Hidden",
      quest.defaultSurface != "Experimental only",
      quest.defaultSurface != "Browse first",
      context.allowedMovement.contains(quest.movement),
      !context.avoidedWorlds.contains(quest.world),
      passesContextFilter(quest, context: context),
      passesSafetyFilter(quest, context: context),
      passesCognitiveFilter(quest, maximum: context.maximumCognitiveLoad)
    else { return false }

    return true
  }

  private func passesContextFilter(
    _ quest: QuestDefinition,
    context: RecommendationContext
  ) -> Bool {
    if context.avoidContextSpecific {
      return quest.defaultSurface == "General default" && quest.context.contains("Anywhere")
    }
    guard quest.defaultSurface == "Contextual default" else { return true }
    let specific = Set(quest.context).subtracting(["Anywhere"])
    return specific.isEmpty || !specific.isDisjoint(with: context.activeContexts)
  }

  private func passesSafetyFilter(
    _ quest: QuestDefinition,
    context: RecommendationContext
  ) -> Bool {
    let safety = Set(quest.safety)
    if safety.contains("DaylightOnly") && !context.activeContexts.contains("Daylight") {
      return false
    }
    if safety.contains("NightSafeOnly") && !context.activeContexts.contains("Night") {
      return false
    }
    if safety.contains("CompanionOnly") && !context.activeContexts.contains("With Companion") {
      return false
    }

    let explicitIntentFlags: Set<String> = [
      "OptionalCamera",
      "OptionalText",
      "OptionalLookup",
      "NoPhoneDrawing",
      "NaturalInteractionOnly",
      "ExitAfterShare",
    ]
    return safety.isDisjoint(with: explicitIntentFlags)
  }

  private func passesCognitiveFilter(
    _ quest: QuestDefinition,
    maximum: String?
  ) -> Bool {
    guard let maximum else { return true }
    let order = ["Very Low": 0, "Low": 1, "Medium": 2, "High": 3]
    return order[quest.cognitiveLoad, default: 3] <= order[maximum, default: 3]
  }

  private func repeatedRecentWorld(in context: RecommendationContext) -> String? {
    let limit = configuration.guardrails.maxSameWorldConsecutive
    let suffix = context.recentWorlds.suffix(limit)
    guard suffix.count == limit, let first = suffix.first,
      suffix.allSatisfy({ $0 == first })
    else { return nil }
    return first
  }

  private func scoreComponents(
    for quest: QuestDefinition,
    context: RecommendationContext
  ) -> ScoreComponents {
    let weights = configuration.weights
    let state = stateFit(for: quest, selectedState: context.selectedState)
    let editorial = editorialPriority(for: quest)
    let novelty = context.recentWorlds.contains(quest.world) ? 0.35 : 1
    let diversity = quest.isFindHeavy && context.recentFindHeavy.last == true ? 0.25 : 1
    let contextFit = quest.context.contains("Anywhere") ? 0.8 : 1
    let worldExposure = configuration.worldBaseExposure[quest.world, default: 0] * 3

    return ScoreComponents(
      state: state * weights.stateFit * 100,
      editorial: editorial * weights.editorialPriority * 100,
      novelty: novelty * weights.novelty * 100,
      diversity: diversity * weights.diversityCorrection * 100,
      context: contextFit * weights.contextConfidence * 100,
      worldExposure: worldExposure
    )
  }

  private func stateFit(
    for quest: QuestDefinition,
    selectedState: ExplorerState?
  ) -> Double {
    guard let selectedState else { return 0.5 }
    switch selectedState {
    case .easy:
      return max(
        quest.moods.contains("Easy") ? 1 : 0,
        ["Very Low", "Low"].contains(quest.cognitiveLoad) ? 0.75 : 0.2
      )
    case .calm:
      return quest.moods.contains("Calm") || quest.world == "Pause" ? 1 : 0.25
    case .think:
      return quest.moods.contains("Think") || quest.depth == "Deep" ? 1 : 0.2
    case .move:
      return quest.world == "Move a Little" || quest.movement == "Under 50m" ? 1 : 0.2
    case .listen:
      return quest.world == "Listen & Sense" || quest.actions.contains("Listen") ? 1 : 0.15
    case .doNothing:
      return quest.world == "Pause" || quest.actions.contains("Pause") ? 1 : 0.1
    }
  }

  private func editorialPriority(for quest: QuestDefinition) -> Double {
    switch quest.rank {
    case "Featured": 1
    case "Recommended": 0.75
    case "Niche": 0.45
    case "Deep Cut": 0.25
    default: 0
    }
  }
}

private struct ScoredCandidate {
  let quest: QuestDefinition
  let components: ScoreComponents
  var total: Double { components.total }
  var summary: String { components.summary }
}

private struct ScoreComponents {
  let state: Double
  let editorial: Double
  let novelty: Double
  let diversity: Double
  let context: Double
  let worldExposure: Double

  var total: Double {
    state + editorial + novelty + diversity + context + worldExposure
  }

  var summary: String {
    String(
      format: "状态 %.1f · 编辑 %.1f · 新鲜度 %.1f · 多样性 %.1f · 情境 %.1f",
      state,
      editorial,
      novelty,
      diversity,
      context
    )
  }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }

  mutating func nextUnitInterval() -> Double {
    Double(next() >> 11) / Double(1 << 53)
  }
}
