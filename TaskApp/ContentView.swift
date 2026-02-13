import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    private enum ScreenshotAction: Hashable {
        case copy
        case save
        case delete
    }

    private struct ActionKey: Hashable {
        let shotID: UUID
        let action: ScreenshotAction
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    @StateObject private var screenshotMonitor = ScreenshotMonitor()
    @State private var editingTaskID: PersistentIdentifier?
    @FocusState private var focusedTaskID: PersistentIdentifier?
    @State private var activeActions: Set<ActionKey> = []
    @State private var hoveredActions: Set<ActionKey> = []
    @State private var hoveredTaskDeleteIDs: Set<PersistentIdentifier> = []
    @State private var isHoveringAddButton = false

    private var totalRows: Int {
        tasks.count + screenshotMonitor.items.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                Section("Screenshots") {
                    if screenshotMonitor.items.isEmpty {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.green)
                                .frame(width: 7, height: 7)
                            Text("監視中: スクリーンショットを待機しています")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
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
                                    flashAction(.copy, for: shot)
                                    screenshotMonitor.copyToPasteboard(shot)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(actionForegroundColor(.copy, for: shot))
                                        .scaleEffect(actionScale(.copy, for: shot))
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(actionBackgroundColor(.copy, for: shot))
                                        )
                                        .animation(.easeInOut(duration: 0.12), value: actionScale(.copy, for: shot))
                                }
                                .buttonStyle(.plain)
                                .onHover { isHovering in
                                    setHovering(isHovering, action: .copy, for: shot)
                                }

                                Button {
                                    flashAction(.save, for: shot)
                                    screenshotMonitor.saveToDesktop(shot)
                                } label: {
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundStyle(actionForegroundColor(.save, for: shot))
                                        .scaleEffect(actionScale(.save, for: shot))
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(actionBackgroundColor(.save, for: shot))
                                        )
                                        .animation(.easeInOut(duration: 0.12), value: actionScale(.save, for: shot))
                                }
                                .buttonStyle(.plain)
                                .onHover { isHovering in
                                    setHovering(isHovering, action: .save, for: shot)
                                }

                                Button(role: .destructive) {
                                    flashAction(.delete, for: shot)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        screenshotMonitor.remove(shot)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(actionForegroundColor(.delete, for: shot))
                                        .scaleEffect(actionScale(.delete, for: shot))
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(actionBackgroundColor(.delete, for: shot))
                                        )
                                        .animation(.easeInOut(duration: 0.12), value: actionScale(.delete, for: shot))
                                }
                                .buttonStyle(.plain)
                                .onHover { isHovering in
                                    setHovering(isHovering, action: .delete, for: shot)
                                }
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
                                    .foregroundStyle(.white)
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
                                    .foregroundStyle(isTaskDeleteHovered(task) ? .red : .red.opacity(0.88))
                                    .scaleEffect(isTaskDeleteHovered(task) ? 1.24 : 1.0)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(isTaskDeleteHovered(task) ? Color.red.opacity(0.18) : .clear)
                                    )
                                    .animation(.easeInOut(duration: 0.12), value: isTaskDeleteHovered(task))
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovering in
                                setTaskDeleteHover(isHovering, for: task)
                            }
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
                    .foregroundStyle(isHoveringAddButton ? .blue : .black)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isHoveringAddButton ? Color.blue.opacity(0.2) : .white)
                    )
                    .scaleEffect(isHoveringAddButton ? 1.22 : 1.0)
                    .shadow(radius: 2, y: 1)
                    .animation(.easeInOut(duration: 0.12), value: isHoveringAddButton)
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                isHoveringAddButton = isHovering
            }
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

    private func isActionActive(_ action: ScreenshotAction, for shot: ScreenshotEntry) -> Bool {
        activeActions.contains(ActionKey(shotID: shot.id, action: action))
    }

    private func flashAction(_ action: ScreenshotAction, for shot: ScreenshotEntry) {
        let key = ActionKey(shotID: shot.id, action: action)
        withAnimation(.easeIn(duration: 0.06)) {
            _ = activeActions.insert(key)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.12)) {
                _ = activeActions.remove(key)
            }
        }
    }

    private func setHovering(_ isHovering: Bool, action: ScreenshotAction, for shot: ScreenshotEntry) {
        let key = ActionKey(shotID: shot.id, action: action)
        if isHovering {
            _ = hoveredActions.insert(key)
        } else {
            _ = hoveredActions.remove(key)
        }
    }

    private func actionScale(_ action: ScreenshotAction, for shot: ScreenshotEntry) -> CGFloat {
        if isActionActive(action, for: shot) {
            return 1.16
        }
        if hoveredActions.contains(ActionKey(shotID: shot.id, action: action)) {
            return 1.24
        }
        return 1.0
    }

    private func isActionHovered(_ action: ScreenshotAction, for shot: ScreenshotEntry) -> Bool {
        hoveredActions.contains(ActionKey(shotID: shot.id, action: action))
    }

    private func actionForegroundColor(_ action: ScreenshotAction, for shot: ScreenshotEntry) -> Color {
        if isActionActive(action, for: shot) {
            switch action {
            case .copy: return .blue
            case .save: return .green
            case .delete: return .red
            }
        }
        if isActionHovered(action, for: shot) {
            switch action {
            case .copy: return .blue
            case .save: return .green
            case .delete: return .red
            }
        }
        if action == .delete {
            return .red.opacity(0.9)
        }
        return .black
    }

    private func actionBackgroundColor(_ action: ScreenshotAction, for shot: ScreenshotEntry) -> Color {
        if isActionActive(action, for: shot) {
            switch action {
            case .copy: return Color.blue.opacity(0.16)
            case .save: return Color.green.opacity(0.16)
            case .delete: return Color.red.opacity(0.16)
            }
        }
        if isActionHovered(action, for: shot) {
            switch action {
            case .copy: return Color.blue.opacity(0.12)
            case .save: return Color.green.opacity(0.12)
            case .delete: return Color.red.opacity(0.12)
            }
        }
        return .clear
    }

    private func isTaskDeleteHovered(_ task: TaskItem) -> Bool {
        hoveredTaskDeleteIDs.contains(task.persistentModelID)
    }

    private func setTaskDeleteHover(_ isHovering: Bool, for task: TaskItem) {
        let id = task.persistentModelID
        if isHovering {
            _ = hoveredTaskDeleteIDs.insert(id)
        } else {
            _ = hoveredTaskDeleteIDs.remove(id)
        }
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

    func saveToDesktop(_ item: ScreenshotEntry) {
        guard
            let tiff = item.image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else { return }

        let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let baseName = URL(fileURLWithPath: item.sourcePath).deletingPathExtension().lastPathComponent
        let fileBase = baseName.isEmpty ? "Screenshot" : baseName
        let targetURL = uniqueDesktopURL(in: desktop, baseName: fileBase, ext: "png")
        try? pngData.write(to: targetURL, options: .atomic)
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
        bringAppToFront()

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
            name.contains("screen") ||
            name.contains("capture") ||
            name.contains("スクリーンショット") ||
            name.contains("スクリーン") ||
            name.contains("画面")

        return isImage && looksLikeScreenshot
    }

    private func uniqueDesktopURL(in directory: URL, baseName: String, ext: String) -> URL {
        var index = 0
        while true {
            let suffix = index == 0 ? "" : " \(index)"
            let candidate = directory.appendingPathComponent("\(baseName)\(suffix)").appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func bringAppToFront() {
        let app = NSRunningApplication.current
        app.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
