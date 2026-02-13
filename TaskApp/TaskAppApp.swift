import SwiftUI
import SwiftData

@main
struct TaskAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 420, minHeight: 520)
        }
        .modelContainer(for: TaskItem.self)
    }
}
