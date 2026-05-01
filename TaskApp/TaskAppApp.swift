import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct TaskAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var captureMonitor = CaptureMonitor()

    var body: some Scene {
        MenuBarExtra {
            ContentView(captureMonitor: captureMonitor)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "camera.viewfinder")
                if !captureMonitor.items.isEmpty {
                    Text("\(captureMonitor.items.count)")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
