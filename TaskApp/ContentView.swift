import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    @StateObject private var screenshotMonitor = ScreenshotMonitor()
    @State private var editingTaskID: PersistentIdentifier?
    @FocusState private var focusedTaskID: PersistentIdentifier?

    private var totalRows: Int {
        tasks.count + screenshotMonitor.items.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                if !screenshotMonitor.items.isEmpty {
                    Section("Screenshots") {
                        ForEach(screenshotMonitor.items) { shot in
                            HStack(spacing: 10) {
                                Image(nsImage: shot.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 92, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text("コピー済み")
                                    .foregroundStyle(.black)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Spacer()

                                Button {
                                    screenshotMonitor.copyToPasteboard(shot)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(.black)
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    screenshotMonitor.remove(shot)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Tasks") {
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
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white)

                                    TextField("タスク名", text: Binding(
                                        get: { task.title },
                                        set: { task.title = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .focused($focusedTaskID, equals: task.persistentModelID)
                                    .onSubmit { finishEditing(task) }
                                }
                                .frame(minHeight: 30)
                            } else {
                                Text(task.title.isEmpty ? "無題タスク" : task.title)
                                    .foregroundStyle(.black)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
        .background(WindowConfigurator(totalRows: totalRows))
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
    let totalRows: Int

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            window.title = ""
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true

            let rowHeight: CGFloat = 38
            let baseHeight: CGFloat = 80
            let targetHeight = max(130, min(560, CGFloat(totalRows) * rowHeight + baseHeight))

            var frame = window.frame
            if abs(frame.height - targetHeight) > 0.5 {
                frame.size.height = targetHeight
                window.setFrame(frame, display: true, animate: true)
            }
        }
    }
}

struct ScreenshotEntry: Identifiable {
    let id = UUID()
    let image: NSImage
    let sourcePath: String
    let fileDate: Date
}

@MainActor
final class ScreenshotMonitor: ObservableObject {
    @Published var items: [ScreenshotEntry] = []

    private var processedPaths: Set<String> = []
    private var timer: Timer?
    private let fm = FileManager.default

    init() {
        seedExisting()
        start()
    }

    deinit {
        timer?.invalidate()
    }

    func remove(_ item: ScreenshotEntry) {
        items.removeAll { $0.id == item.id }
    }

    func copyToPasteboard(_ item: ScreenshotEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        _ = pb.writeObjects([item.image])
    }

    private func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scan()
            }
        }
        timer?.tolerance = 0.1
    }

    private func screenshotDirectory() -> URL {
        // macOS screenshot save location (defaults domain)
        if let raw = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture")?["location"] as? String {
            let expanded = NSString(string: raw).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return fm.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    private func seedExisting() {
        let dir = screenshotDirectory()
        guard let urls = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in urls where isScreenshot(url) {
            processedPaths.insert(url.path)
        }
    }

    private func scan() {
        let dir = screenshotDirectory()

        guard let urls = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let candidates = urls
            .filter { isScreenshot($0) && !processedPaths.contains($0.path) }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return l > r
            }

        for url in candidates {
            process(url: url)
        }
    }

    private func process(url: URL) {
        // 書き込み途中対策で数回リトライ
        var image: NSImage?
        for _ in 0..<6 {
            if let data = try? Data(contentsOf: url), let loaded = NSImage(data: data) {
                image = loaded
                break
            }
            Thread.sleep(forTimeInterval: 0.08)
        }
        guard let image else { return }

        processedPaths.insert(url.path)

        let pb = NSPasteboard.general
        pb.clearContents()
        _ = pb.writeObjects([image])

        let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        items.insert(ScreenshotEntry(image: image, sourcePath: url.path, fileDate: created), at: 0)

        // Finderに残さない
        try? fm.removeItem(at: url)
    }

    private func isScreenshot(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        let isImage = ["png", "jpg", "jpeg", "heic", "tiff"].contains(ext)
        let looksLikeScreenshot =
            name.contains("screenshot") ||
            name.contains("screen shot") ||
            name.contains("スクリーンショット")

        return isImage && looksLikeScreenshot
    }
}

