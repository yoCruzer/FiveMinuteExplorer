import SwiftUI

struct ExploreView: View {
  @Environment(\.dismiss) private var dismiss
  let quests: [QuestDefinition]
  let onSelect: (QuestDefinition, String) -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 26) {
          shelfGroup(title: "此刻想要什么？", shelves: stateShelves)
          shelfGroup(title: "换一个世界", shelves: worldShelves)
          shelfGroup(title: "按场景看看", shelves: contextShelves)
        }
        .padding(.vertical, 18)
      }
      .navigationTitle("探索更多")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("完成") { dismiss() }
        }
      }
    }
  }

  @ViewBuilder
  private func shelfGroup(title: String, shelves: [ExploreShelf]) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title)
        .font(.title2.weight(.semibold))
        .padding(.horizontal, 20)
      ForEach(shelves) { shelf in
        LibraryShelfView(shelf: shelf) { quest in
          onSelect(quest, shelf.source)
          dismiss()
        }
      }
    }
  }

  private var visibleQuests: [QuestDefinition] {
    quests
      .filter { $0.catalogStatus == "Cataloged" && $0.rank != "Hidden" }
      .sorted(by: libraryOrder)
  }

  private var stateShelves: [ExploreShelf] {
    let definitions: [(String, String, (QuestDefinition) -> Bool)] = [
      ("easy", "轻松一点", { $0.moods.contains("Easy") }),
      ("calm", "安静一点", { $0.moods.contains("Calm") || $0.world == "Pause" }),
      ("think", "想想为什么", { $0.moods.contains("Think") || $0.depth == "Deep" }),
      ("move", "动一下", { $0.world == "Move a Little" || $0.movement == "Under 50m" }),
      ("listen", "听一听", { $0.world == "Listen & Sense" || $0.actions.contains("Listen") }),
      ("nothing", "什么也不做", { $0.world == "Pause" || $0.actions.contains("Pause") }),
      ("weird", "有点怪", { $0.moods.contains("Weird") }),
      ("create", "想创造 / 拍照", { $0.world == "Imagine & Create" }),
    ]
    return definitions.map { id, title, predicate in
      ExploreShelf(
        id: "state-\(id)",
        title: title,
        source: "explore_state",
        quests: visibleQuests.filter(predicate)
      )
    }
  }

  private var worldShelves: [ExploreShelf] {
    WorldPresentation.ordered.map { world in
      ExploreShelf(
        id: "world-\(world)",
        title: WorldPresentation.title(for: world),
        source: "explore_world",
        quests: visibleQuests.filter { $0.world == world }
      )
    }
  }

  private var contextShelves: [ExploreShelf] {
    let definitions: [(String, String, Set<String>)] = [
      ("waiting", "等待时", ["Waiting"]),
      ("home", "在家", ["Home"]),
      ("work", "工作 / 学校", ["Work", "School", "Work / School"]),
      ("cafe", "咖啡馆 / 餐厅", ["Cafe", "Restaurant", "Cafe / Restaurant"]),
      ("transit", "通勤途中", ["Transit"]),
      ("travel", "旅行中", ["Travel"]),
      ("night", "夜晚", ["Night"]),
      ("familiar", "熟悉的地方", ["Familiar Place"]),
      ("nature", "附近有自然", ["Nature Nearby"]),
    ]
    return definitions.compactMap { id, title, contexts in
      let matches = visibleQuests.filter { !Set($0.context).isDisjoint(with: contexts) }
      guard !matches.isEmpty else { return nil }
      return ExploreShelf(
        id: "context-\(id)",
        title: title,
        source: "explore_context",
        quests: matches
      )
    }
  }

  private func libraryOrder(_ lhs: QuestDefinition, _ rhs: QuestDefinition) -> Bool {
    let surface = ["General default": 0, "Contextual default": 1, "Browse first": 2]
    let rank = ["Featured": 0, "Recommended": 1, "Niche": 2, "Deep Cut": 3, "Experimental": 4]
    let lhsKey = (surface[lhs.defaultSurface, default: 9], rank[lhs.rank, default: 9], lhs.id)
    let rhsKey = (surface[rhs.defaultSurface, default: 9], rank[rhs.rank, default: 9], rhs.id)
    return lhsKey < rhsKey
  }
}

private struct ExploreShelf: Identifiable {
  let id: String
  let title: String
  let source: String
  let quests: [QuestDefinition]
}

private struct LibraryShelfView: View {
  let shelf: ExploreShelf
  let onSelect: (QuestDefinition) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(shelf.title)
          .font(.headline)
        Spacer()
        NavigationLink("查看全部") {
          ShelfListView(shelf: shelf, onSelect: onSelect)
        }
        .font(.subheadline)
      }
      .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 12) {
          ForEach(shelf.quests.prefix(10)) { quest in
            Button {
              onSelect(quest)
            } label: {
              VStack(alignment: .leading, spacing: 8) {
                Text(quest.title)
                  .font(.headline)
                  .foregroundStyle(.primary)
                  .lineLimit(2)
                Text(quest.text)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                  .lineLimit(3)
                Spacer(minLength: 0)
                Text("\(quest.localizedTime) · \(quest.localizedMovement)")
                  .font(.caption)
                  .foregroundStyle(.tertiary)
              }
              .frame(width: 220, height: 150, alignment: .leading)
              .padding(16)
              .background(
                Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 18)
              )
            }
            .buttonStyle(.plain)
            .accessibilityHint("选择后返回主页并专注这条 Quest")
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }
}

private struct ShelfListView: View {
  let shelf: ExploreShelf
  let onSelect: (QuestDefinition) -> Void

  var body: some View {
    List(shelf.quests) { quest in
      Button {
        onSelect(quest)
      } label: {
        VStack(alignment: .leading, spacing: 5) {
          Text(quest.title)
            .font(.headline)
            .foregroundStyle(.primary)
          Text(quest.text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          Text("\(quest.localizedTime) · \(quest.localizedMovement)")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
      }
      .buttonStyle(.plain)
    }
    .navigationTitle(shelf.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
