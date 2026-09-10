import SwiftUI

struct ExploreView: View {
  @Environment(\.dismiss) private var dismiss
  let quests: [QuestDefinition]
  let onSelect: (QuestDefinition, String, String) -> Void

  var body: some View {
    NavigationStack {
      List {
        categorySection("此刻想要什么？", shelves: stateShelves)
        categorySection("换一种方式看世界", shelves: worldShelves)
        categorySection("你现在在哪？", shelves: contextShelves)
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

  private func categorySection(_ title: String, shelves: [ExploreShelf]) -> some View {
    Section(title) {
      ForEach(shelves) { shelf in
        NavigationLink(shelf.title) {
          ShelfListView(shelf: shelf) { quest in
            onSelect(quest, shelf.source, shelf.sourceDetail)
            dismiss()
          }
        }
        .frame(minHeight: 44)
      }
    }
  }

  private var visibleQuests: [QuestDefinition] {
    QuestMatchingPolicy.libraryQuests(quests)
  }

  private var stateShelves: [ExploreShelf] {
    ExplorerState.allCases.map { state in
      ExploreShelf(
        title: state.title, source: "explore_state", sourceDetail: state.sourceDetail,
        quests: visibleQuests.filter { QuestMatchingPolicy.stateFit($0, state: state) >= 0.75 })
    } + [
      ExploreShelf(
        title: "有点怪", source: "explore_state", sourceDetail: "weird",
        quests: visibleQuests.filter { $0.moods.contains("Weird") }),
      ExploreShelf(
        title: "想创造 / 拍照", source: "explore_state", sourceDetail: "create",
        quests: visibleQuests.filter { $0.world == "Imagine & Create" }),
    ]
  }

  private var worldShelves: [ExploreShelf] {
    WorldPresentation.ordered.map { world in
      ExploreShelf(
        title: WorldPresentation.title(for: world), source: "explore_world",
        sourceDetail: world, quests: visibleQuests.filter { $0.world == world })
    }
  }

  private var contextShelves: [ExploreShelf] {
    ContextProfile.allCases.compactMap { profile in
      let matches = visibleQuests.filter(profile.matches)
      guard !matches.isEmpty else { return nil }
      return ExploreShelf(
        title: profile.title, source: "explore_context",
        sourceDetail: profile.rawValue, quests: matches)
    }
  }
}

private struct ExploreShelf: Identifiable {
  let title: String
  let source: String
  let sourceDetail: String
  let quests: [QuestDefinition]
  var id: String { "\(source):\(sourceDetail)" }
}

private struct ShelfListView: View {
  let shelf: ExploreShelf
  let onSelect: (QuestDefinition) -> Void
  @State private var visibleCount = 10

  var body: some View {
    List {
      ForEach(shelf.quests.prefix(visibleCount)) { quest in
        Button {
          onSelect(quest)
        } label: {
          VStack(alignment: .leading, spacing: 8) {
            Text(quest.title).font(.headline).foregroundStyle(.primary)
            Text(quest.text).font(.subheadline).foregroundStyle(.secondary)
            Text("\(quest.localizedTime) · \(quest.localizedMovement)")
              .font(.caption).foregroundStyle(.secondary)
            if !quest.requirementLabels.isEmpty {
              Text(quest.requirementLabels.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          .fixedSize(horizontal: false, vertical: true)
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library-quest-\(quest.id)")
        .accessibilityHint("选择后返回主页并专注这条 Quest")
      }
      if visibleCount < shelf.quests.count {
        Button("显示更多") { visibleCount += 10 }
          .frame(minHeight: 44)
      }
    }
    .navigationTitle(shelf.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
