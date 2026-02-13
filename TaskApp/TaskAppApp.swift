import SwiftUI
import SwiftData
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let image = NSImage(named: "RuntimeIcon") {
            NSApp.applicationIconImage = image
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // ウィンドウを閉じてもアプリは終了しない
        false
    }
}

@main
struct TaskAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("TaskApp", id: "main") {
            ContentView()
        }
        .defaultSize(width: 360, height: 220)
        .windowStyle(.hiddenTitleBar)
        .modelContainer(for: TaskItem.self)

        MenuBarExtra("TaskApp", systemImage: "checklist") {
            Button("開く") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("終了") {
                NSApp.terminate(nil)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
