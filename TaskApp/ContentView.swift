import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    @State private var newTitle = ""
    @State private var didPositionWindow = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("タスクを入力", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTask)

                Button("追加", action: addTask)
                    .keyboardShortcut(.return, modifiers: [.command])
            }

            List(tasks) { task in
                Button {
                    task.isDone.toggle()
                    try? modelContext.save()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isDone ? .green : .secondary)

                        Text(task.title)
                            .strikethrough(task.isDone)
                            .foregroundStyle(task.isDone ? .secondary : .primary)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .overlay {
                if tasks.isEmpty {
                    Text("タスクはまだありません")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(WindowAccessor { window in
            positionWindowAtBottom(window)
        })
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        modelContext.insert(TaskItem(title: title))
        try? modelContext.save()
        newTitle = ""
    }

    private func positionWindowAtBottom(_ window: NSWindow) {
        guard !didPositionWindow, let screen = window.screen ?? NSScreen.main else { return }
        didPositionWindow = true

        DispatchQueue.main.async {
            let visible = screen.visibleFrame
            let x = visible.minX + (visible.width - window.frame.width) / 2
            let y = visible.minY + 24
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}

