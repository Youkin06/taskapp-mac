import SwiftUI
import SwiftData
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // ウィンドウを閉じてもアプリは終了しない
        false
    }
}

@main
struct TaskAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("TaskApp", id: "main") {
            ContentView()
        }
        .defaultSize(width: 360, height: 220)
        .windowStyle(.hiddenTitleBar)
        .modelContainer(for: TaskItem.self)
    }
}
