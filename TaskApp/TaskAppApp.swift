import SwiftUI
import SwiftData

@main
struct TaskAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(for: TaskItem.self)
    }
}

