import SwiftData
import SwiftUI

@main
struct FiveMinuteExplorerApp: App {
  private let modelContainer: ModelContainer
  @StateObject private var store: ExplorerStore

  init() {
    let container: ModelContainer
    let storageDiagnostic: String?
    do {
      container = try ModelContainer(for: QuestEventRecord.self)
      storageDiagnostic = nil
    } catch {
      let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
      container = try! ModelContainer(
        for: QuestEventRecord.self,
        configurations: configuration
      )
      storageDiagnostic = "SwiftData 持久化不可用，当前事件仅保存在内存：\(error.localizedDescription)"
    }

    modelContainer = container
    _store = StateObject(
      wrappedValue: ExplorerStore(
        modelContext: container.mainContext,
        storageDiagnostic: storageDiagnostic
      )
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
    }
    .modelContainer(modelContainer)
  }
}
