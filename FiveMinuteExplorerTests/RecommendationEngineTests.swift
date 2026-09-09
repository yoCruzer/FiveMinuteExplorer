import Testing

@testable import FiveMinuteExplorer

struct RecommendationEngineTests {
  private let configuration = RecommendationConfiguration(
    version: "v1",
    weights: .init(
      stateFit: 0.30,
      editorialPriority: 0.15,
      personalTaste: 0.15,
      novelty: 0.15,
      diversityCorrection: 0.15,
      contextConfidence: 0.10
    ),
    worldBaseExposure: [:],
    guardrails: .init(
      serendipityRate: 0.20,
      sameSeedCooldownDays: 60,
      canonicalLensCooldownServes: 3,
      maxSameWorldConsecutive: 2,
      minDistinctWorldsPer7Serves: 4,
      maxFindHeavyConsecutive: 2,
      targetNonVisualRate: 0.20,
      pauseBaseRateRange: [0.05, 0.08],
      maxDefaultRerollsBeforeStatePrompt: 2
    )
  )

  private var engine: RecommendationEngineV1 {
    RecommendationEngineV1(configuration: configuration)
  }

  @Test
  func experimentalIsFilteredFromGeneralDefault() {
    let experimental = makeQuest(id: 1, rank: "Experimental", surface: "Experimental only")
    let fallback = makeQuest(id: 2)

    let result = engine.recommend(
      from: [experimental, fallback],
      context: RecommendationContext(randomSeed: 1)
    )

    #expect(result?.quest.id == 2)
  }

  @Test
  func contextualQuestIsFilteredWhenContextDoesNotMatch() {
    let contextual = makeQuest(
      id: 1,
      context: ["Home"],
      surface: "Contextual default"
    )
    let fallback = makeQuest(id: 2)

    let result = engine.recommend(
      from: [contextual, fallback],
      context: RecommendationContext(activeContexts: ["Anywhere"], randomSeed: 2)
    )

    #expect(result?.quest.id == 2)
  }

  @Test
  func movementFilterExcludesDisallowedMovement() {
    let moving = makeQuest(id: 1, movement: "Under 50m")
    let stationary = makeQuest(id: 2)

    let result = engine.recommend(
      from: [moving, stationary],
      context: RecommendationContext(allowedMovement: ["Stay Here"], randomSeed: 3)
    )

    #expect(result?.quest.id == 2)
  }

  @Test
  func recentSeedCooldownExcludesExactSeed() {
    let recent = makeQuest(id: 1, lens: "Lens Recent")
    let fresh = makeQuest(id: 2, lens: "Lens Fresh")

    let result = engine.recommend(
      from: [recent, fresh],
      context: RecommendationContext(recentSeedIDs: [1], randomSeed: 4)
    )

    #expect(result?.quest.id == 2)
  }

  @Test
  func canonicalLensCooldownExcludesRecentLens() {
    let repeated = makeQuest(id: 1, lens: "Repeated")
    let fresh = makeQuest(id: 2, lens: "Fresh")

    let result = engine.recommend(
      from: [repeated, fresh],
      context: RecommendationContext(
        recentCanonicalLenses: ["Other", "Repeated"],
        randomSeed: 5
      )
    )

    #expect(result?.quest.id == 2)
  }

  @Test
  func worldRepetitionGuardrailUsesAlternativeWhenAvailable() {
    let repeated = makeQuest(id: 1, world: "Same", lens: "Lens 1")
    let alternative = makeQuest(id: 2, world: "Different", lens: "Lens 2")

    let result = engine.recommend(
      from: [repeated, alternative],
      context: RecommendationContext(
        recentWorlds: ["Same", "Same"],
        randomSeed: 6
      )
    )

    #expect(result?.quest.id == 2)
  }

  @Test
  func findFatigueGuardrailUsesNonFindAlternative() {
    let find = makeQuest(id: 1, lens: "Lens 1", actions: ["Find"])
    let listen = makeQuest(id: 2, lens: "Lens 2", actions: ["Listen"])

    let result = engine.recommend(
      from: [find, listen],
      context: RecommendationContext(
        recentFindHeavy: [true, true],
        randomSeed: 7
      )
    )

    #expect(result?.quest.id == 2)
  }

  @Test
  func fixedInputAndRandomSeedAreDeterministic() {
    let quests = (1...20).map {
      makeQuest(id: $0, world: "World \($0 % 4)", lens: "Lens \($0)")
    }
    let context = RecommendationContext(randomSeed: 0xC0FFEE)

    let first = engine.recommend(from: quests, context: context)
    let second = engine.recommend(from: quests, context: context)

    #expect(first?.quest.id == second?.quest.id)
    #expect(first?.usedSerendipity == second?.usedSerendipity)
  }

  @Test
  func selectedStateFitOutranksEditorialRank() {
    let featuredVisual = makeQuest(
      id: 1,
      world: "Look Closer",
      lens: "Visual",
      moods: ["Easy"],
      rank: "Featured"
    )
    let listening = makeQuest(
      id: 2,
      world: "Listen & Sense",
      lens: "Sound",
      actions: ["Listen"],
      moods: ["Calm"],
      rank: "Recommended"
    )

    let result = engine.recommend(
      from: [featuredVisual, listening],
      context: RecommendationContext(selectedState: .listen, randomSeed: 9)
    )

    #expect(result?.quest.id == 2)
  }

  @Test func fallbackNeverRelaxesSafety() {
    let safe = makeQuest(id: 1)
    let unsafe = makeQuest(id: 2, safety: ["PublicSpaceOnly"])
    let result = engine.recommend(
      from: [safe, unsafe],
      context: RecommendationContext(
        latestSeedIDs: [1, 2], recentSeedIDs: [1, 2], randomSeed: 9))
    #expect(result?.quest.id == 1)
    #expect(result?.fallbackLevel == 3)
  }

  @Test func fallbackRelaxesLensThenLongSeedCooldown() {
    let quest = makeQuest(id: 1)
    let lens = engine.recommend(
      from: [quest],
      context: RecommendationContext(
        recentCanonicalLenses: ["Lens A"], randomSeed: 9))
    #expect(lens?.fallbackLevel == 1)
    let seed = engine.recommend(
      from: [quest],
      context: RecommendationContext(
        recentSeedIDs: [1], randomSeed: 9))
    #expect(seed?.fallbackLevel == 2)
  }

  @Test func publicSpaceRequiresPositiveEvidence() {
    let quest = makeQuest(id: 1, safety: ["PublicSpaceOnly"])
    for profile: ContextProfile? in [nil, .home, .night, .waiting] {
      #expect(
        engine.recommend(
          from: [quest],
          context: RecommendationContext(
            contextProfile: profile, randomSeed: 9)) == nil)
    }
    #expect(
      engine.recommend(
        from: [quest],
        context: RecommendationContext(
          contextProfile: .transit, randomSeed: 9)) != nil)
  }

  @Test func allSafetyFlagsRemainHardEvenWhenSeedsExhausted() {
    for (flag, confirmation) in [
      ("DaylightOnly", "Daylight"),
      ("NightSafeOnly", "Safe Lit Space"), ("CompanionOnly", "With Companion"),
    ] {
      let quest = makeQuest(id: 1, safety: [flag])
      #expect(
        engine.recommend(
          from: [quest],
          context: RecommendationContext(
            recentSeedIDs: [1], randomSeed: 9)) == nil)
      #expect(
        engine.recommend(
          from: [quest],
          context: RecommendationContext(
            activeContexts: [confirmation], recentSeedIDs: [1], randomSeed: 9)) != nil)
    }
    let night = makeQuest(id: 1, safety: ["NightSafeOnly"])
    #expect(
      engine.recommend(
        from: [night],
        context: RecommendationContext(
          activeContexts: ["Night"], randomSeed: 9)) == nil)
  }

  @Test func moveIncludesShortWalkButDoesNotConfirmSafeWalkingArea() {
    let walk = makeQuest(id: 1, movement: "Short Walk")
    let context = RecommendationContext(
      selectedState: .move,
      allowedMovement: ["Stay Here", "Few Steps", "Under 50m", "Short Walk"], randomSeed: 9)
    #expect(engine.recommend(from: [walk], context: context)?.quest.id == 1)
    #expect(QuestMatchingPolicy.stateFit(walk, state: .move) == 1)
    let restricted = makeQuest(
      id: 2, movement: "Short Walk", context: ["Safe Walking Area"], surface: "Contextual default")
    #expect(engine.recommend(from: [restricted], context: context) == nil)
  }

  private func makeQuest(
    id: Int,
    world: String = "Look A",
    lens: String = "Lens A",
    actions: [String] = ["Notice"],
    moods: [String] = ["Easy"],
    movement: String = "Stay Here",
    context: [String] = ["Anywhere"],
    cognitiveLoad: String = "Low",
    rank: String = "Recommended",
    surface: String = "General default",
    safety: [String] = ["S0"]
  ) -> QuestDefinition {
    QuestDefinition(
      id: id,
      originalSeed: "Seed \(id)",
      title: "Quest \(id)",
      text: "Text \(id)",
      world: world,
      rawLens: [lens],
      canonicalLens: lens,
      actions: actions,
      moods: moods,
      time: "1–3 min",
      energy: "Low",
      cognitiveLoad: cognitiveLoad,
      movement: movement,
      environment: ["Anywhere"],
      context: context,
      depth: "Light",
      rank: rank,
      defaultSurface: surface,
      safety: safety,
      whyKeep: "Test",
      catalogStatus: "Cataloged"
    )
  }
}
