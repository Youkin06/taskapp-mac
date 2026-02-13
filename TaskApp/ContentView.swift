import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    @State private var editingTaskID: PersistentIdentifier?
    @FocusState private var focusedTaskID: PersistentIdentifier?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                ForEach(tasks) { task in
                    HStack(spacing: 10) {
                        Button {
                            task.isDone.toggle()
                            try? modelContext.save()
                        } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isDone ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        if editingTaskID == task.persistentModelID {
                            TextField("タスク名", text: Binding(
                                get: { task.title },
                                set: { task.title = $0 }
                            ))
                            .focused($focusedTaskID, equals: task.persistentModelID)
                            .onSubmit { finishEditing(task) }
                        } else {
                            Text(task.title.isEmpty ? "無題タスク" : task.title)
                                .strikethrough(task.isDone)
                                .foregroundStyle(task.isDone ? .secondary : .primary)
                                .onTapGesture {
                                    editingTaskID = task.persistentModelID
                                    focusedTaskID = task.persistentModelID
                                }
                        }

                        Spacer()

                        Button(role: .destructive) {
                            deleteTask(task)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.clear)

            Button {
                addTaskAndStartEditing()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white))
                    .shadow(radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(.clear)
        .background(WindowConfigurator(taskCount: tasks.count))
    }

    private func addTaskAndStartEditing() {
        let newTask = TaskItem(title: "")
        modelContext.insert(newTask)
        try? modelContext.save()

        editingTaskID = newTask.persistentModelID
        DispatchQueue.main.async {
            focusedTaskID = newTask.persistentModelID
        }
    }

    private func finishEditing(_ task: TaskItem) {
        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if task.title.isEmpty {
            modelContext.delete(task)
        }
        try? modelContext.save()
        editingTaskID = nil
        focusedTaskID = nil
    }

    private func deleteTask(_ task: TaskItem) {
        modelContext.delete(task)
        try? modelContext.save()
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    let taskCount: Int

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            window.title = ""
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true

            let rowHeight: CGFloat = 36
            let baseHeight: CGFloat = 44
            let targetHeight = max(110, min(460, CGFloat(taskCount) * rowHeight + baseHeight))
            let targetWidth: CGFloat = 360

            if let screen = window.screen ?? NSScreen.main {
                let visible = screen.visibleFrame
                let x = visible.midX - targetWidth / 2
                let y = visible.minY + 20
                let frame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
                window.setFrame(frame, display: true, animate: true)
            }
        }
    }
}

