import SwiftUI

struct HomeView: View {
  @ObservedObject var store: ExplorerStore

  var body: some View {
    VStack(spacing: 0) {
      stateSelector
      Group {
        if let quest = store.currentQuest {
          ScrollView {
            QuestCard(
              quest: quest,
              onMore: { store.recordTaste(more: true) },
              onLess: { store.recordTaste(more: false) }
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
          }
        } else if let catalogError = store.catalogError {
          CatalogUnavailableView(message: catalogError)
        } else {
          ProgressView("正在找一条合适的 Quest…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      VStack(spacing: 10) {
        Button("不适合我") { store.skipCurrent() }
          .buttonStyle(.bordered)
          .controlSize(.large)
          .frame(maxWidth: .infinity)
          .disabled(store.currentQuest == nil)
          .accessibilityHint("换一条 Quest；连续跳过后会询问原因")
        Button("探索更多") { store.isExplorePresented = true }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .frame(maxWidth: .infinity)
          .disabled(store.quests.isEmpty)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 18)
    }
    .navigationTitle("5分钟探索")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Lab", systemImage: "wrench.and.screwdriver") {
            store.isLabPresented = true
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("更多选项")
      }
    }
  }

  private var stateSelector: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        StateChip(title: "随便一个", isSelected: store.selectedState == nil) {
          store.selectState(nil)
        }
        ForEach(ExplorerState.allCases) { state in
          StateChip(title: state.title, isSelected: store.selectedState == state) {
            store.selectState(state)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
    }
    .accessibilityLabel("当前状态")
  }
}

private struct StateChip: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(title, action: action)
      .font(.subheadline.weight(isSelected ? .semibold : .regular))
      .buttonStyle(.bordered)
      .buttonBorderShape(.capsule)
      .tint(isSelected ? .accentColor : .secondary)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private struct QuestCard: View {
  let quest: QuestDefinition
  let onMore: () -> Void
  let onLess: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(alignment: .top) {
        Text(quest.title)
          .font(.title.weight(.semibold))
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 8)
        Menu {
          Button("多来点这种", systemImage: "hand.thumbsup", action: onMore)
          Button("少来点这种", systemImage: "hand.thumbsdown", action: onLess)
        } label: {
          Image(systemName: "ellipsis")
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Quest 偏好")
      }
      Text(quest.text)
        .font(.title3)
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 14) {
        Label(quest.localizedTime, systemImage: "clock")
        Label(quest.localizedMovement, systemImage: "figure.stand")
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
      Text("读完就可以把手机收起来。")
        .font(.footnote)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: 560, alignment: .leading)
    .padding(24)
    .background(
      Color(uiColor: .secondarySystemBackground),
      in: RoundedRectangle(cornerRadius: 22)
    )
  }
}

private struct CatalogUnavailableView: View {
  let message: String

  var body: some View {
    ContentUnavailableView {
      Label("Quest 目录暂不可用", systemImage: "exclamationmark.triangle")
    } description: {
      Text("请稍后重试。详细信息可在 Lab 中查看。\n\(message)")
    }
    .padding()
  }
}
