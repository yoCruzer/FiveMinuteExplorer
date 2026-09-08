import SwiftUI

struct ContentView: View {
  @ObservedObject var store: ExplorerStore
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack {
      if store.hasSeenIntro {
        HomeView(store: store)
      } else {
        IntroView { store.completeIntro() }
      }
    }
    .task { store.startIfNeeded() }
    .onChange(of: scenePhase) { _, newPhase in
      switch newPhase {
      case .active: store.appDidBecomeActive()
      case .background: store.appDidEnterBackground()
      case .inactive: break
      @unknown default: break
      }
    }
    .sheet(isPresented: $store.isExplorePresented) {
      ExploreView(quests: store.quests, onSelect: store.selectFromLibrary)
    }
    .sheet(isPresented: $store.isLabPresented) {
      LabView(store: store)
    }
    .sheet(
      isPresented: $store.isSkipHelpPresented,
      onDismiss: store.skipHelpDidDismiss
    ) {
      SkipHelpView(store: store)
        .presentationDetents([.medium, .large])
    }
    .sheet(
      isPresented: $store.isFeedbackPresented,
      onDismiss: store.dismissFeedback
    ) {
      FeedbackPromptView(store: store)
        .presentationDetents([.height(310)])
    }
  }
}

private struct IntroView: View {
  let onStart: () -> Void

  var body: some View {
    VStack(spacing: 28) {
      Spacer()
      VStack(alignment: .leading, spacing: 20) {
        Image(systemName: "eye")
          .font(.title)
          .foregroundStyle(.tint)
          .accessibilityHidden(true)
        Text("给我 5 分钟，让我重新看见这里")
          .font(.largeTitle.weight(.semibold))
        VStack(alignment: .leading, spacing: 12) {
          Text("打开，拿到一个现实世界的小任务。")
          Text("读完就可以把手机收起来。")
          Text("不用打卡，也不需要证明完成。")
        }
        .foregroundStyle(.secondary)
      }
      .frame(maxWidth: 520, alignment: .leading)
      Spacer()
      Button("开始探索", action: onStart)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityHint("开始并获得第一条 Quest")
    }
    .padding(28)
  }
}

private struct FeedbackPromptView: View {
  @ObservedObject var store: ExplorerStore

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(alignment: .top) {
        Text("刚才那条有没有让你注意到本来不会注意的东西？")
          .font(.title3.weight(.semibold))
        Spacer()
        Button {
          store.dismissFeedback()
        } label: {
          Image(systemName: "xmark")
        }
        .accessibilityLabel("暂不回答")
      }
      HStack(spacing: 12) {
        ForEach([FeedbackValue.yes, .no, .notTried], id: \.rawValue) { value in
          Button(value.title) { store.submitFeedback(value) }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
      }
      Text("这不是完成打卡，只帮助我们理解这条 Quest 有没有带来注意力转移。")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(24)
  }
}

private struct SkipHelpView: View {
  @ObservedObject var store: ExplorerStore

  var body: some View {
    NavigationStack {
      List {
        Section("哪里不太合适？") {
          ForEach(SkipReason.allCases) { reason in
            Button(reason.title) { store.resolvePendingSkip(reason: reason) }
          }
        }
        Section("换个状态") {
          ForEach(ExplorerState.allCases) { state in
            Button(state.title) { store.chooseStateFromSkip(state) }
          }
        }
        Section {
          Button("去探索更多") { store.openExploreFromSkip() }
        }
      }
      .navigationTitle("换个方向")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
