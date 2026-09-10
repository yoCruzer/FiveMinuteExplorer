import SwiftUI

struct LabView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var store: ExplorerStore

  var body: some View {
    NavigationStack {
      Form {
        Section("Catalog") {
          LabeledContent("版本", value: store.catalogVersion)
          LabeledContent("Quest 数量", value: "\(store.quests.count)")
        }

        Section("当前 Quest") {
          if let quest = store.currentQuest {
            LabeledContent("Seed ID", value: "#\(quest.id)")
            LabeledContent("World", value: quest.world)
            LabeledContent("Canonical Lens", value: quest.canonicalLens)
            LabeledContent("Rank", value: quest.rank)
            LabeledContent("Default Surface", value: quest.defaultSurface)
          } else {
            Text("当前没有活动 Quest")
              .foregroundStyle(.secondary)
          }
        }

        Section("推荐状态") {
          LabeledContent("状态", value: store.selectedState?.title ?? "随便一个")
          LabeledContent("Context", value: store.activeContexts.joined(separator: ", "))
          LabeledContent("Source", value: store.lastRecommendationSource)
          VStack(alignment: .leading, spacing: 6) {
            Text("Score")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(store.lastRecommendationScore)
              .font(.footnote.monospaced())
              .textSelection(.enabled)
          }
        }

        Section("最近 serve / skip") {
          if relevantEvents.isEmpty {
            Text("暂无事件")
              .foregroundStyle(.secondary)
          } else {
            ForEach(relevantEvents, id: \.id) { event in
              VStack(alignment: .leading, spacing: 3) {
                Text(eventTitle(event))
                  .font(.subheadline.weight(.medium))
                Text(event.timestamp, format: .dateTime.hour().minute().second())
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }

        Section("事件导出") {
          Button("生成事件 JSON", systemImage: "doc.badge.gearshape") {
            store.exportEvents()
          }
          if let url = store.exportURL {
            ShareLink(item: url) {
              Label("分享 JSON", systemImage: "square.and.arrow.up")
            }
          }
          if let error = store.exportError {
            Text(error)
              .font(.footnote)
              .foregroundStyle(.red)
          }
        }

        if !store.diagnostics.isEmpty {
          Section("Diagnostics") {
            ForEach(Array(store.diagnostics.enumerated()), id: \.offset) { _, item in
              Text(item)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
            }
          }
        }

        Section("Debug") {
          Button("重置首次说明", role: .destructive) {
            store.resetIntro()
            dismiss()
          }
        }
      }
      .navigationTitle("Lab")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("完成") { dismiss() }
        }
      }
    }
  }

  private var relevantEvents: [QuestEventRecord] {
    Array(
      store.recentEvents.filter {
        $0.type == QuestEventType.questServed.rawValue
          || $0.type == QuestEventType.questSkipped.rawValue
      }.prefix(10))
  }

  private func eventTitle(_ event: QuestEventRecord) -> String {
    let action = event.type == QuestEventType.questServed.rawValue ? "served" : "skipped"
    let seed = event.seedID.map { "#\($0)" } ?? "—"
    let suffix = event.skipReason.map { " · \($0)" } ?? ""
    return "\(action) \(seed)\(suffix)"
  }
}
