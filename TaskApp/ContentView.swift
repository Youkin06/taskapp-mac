import SwiftUI
import SwiftData
import AppKit
import AVFoundation

struct ContentView: View {
    private enum CaptureAction: Hashable {
        case copy
        case save
        case delete
    }

    private struct CaptureActionKey: Hashable {
        let itemID: UUID
        let action: CaptureAction
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    @StateObject private var captureMonitor = CaptureMonitor()
    @State private var editingTaskID: PersistentIdentifier?
    @FocusState private var focusedTaskID: PersistentIdentifier?

    @State private var hoveredCaptureActions: Set<CaptureActionKey> = []
    @State private var hoveredTaskDeleteIDs: Set<PersistentIdentifier> = []
    @State private var isHoveringAddButton = false

    private var totalRows: Int {
        tasks.count + captureMonitor.items.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                Section {
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
                                    .strikethrough(task.isDone, color: .black)
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

                            Button {
                                deleteTask(task)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(isTaskDeleteHovered(task) ? .red : .red.opacity(0.88))
                                    .scaleEffect(isTaskDeleteHovered(task) ? 1.22 : 1.0)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(isTaskDeleteHovered(task) ? Color.red.opacity(0.16) : .clear)
                                    )
                                    .animation(.easeInOut(duration: 0.12), value: isTaskDeleteHovered(task))
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                setTaskDeleteHover(hovering, for: task)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section {
                    if captureMonitor.items.isEmpty {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.green)
                                .frame(width: 7, height: 7)
                            Text("監視中: スクリーンショット / 録画を待機")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(captureMonitor.items) { item in
                            HStack(spacing: 10) {
                                previewView(for: item)

                                Text(item.kind == .video ? "動画を一時保存中" : "画像をコピー済み")
                                    .foregroundStyle(.black)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Spacer()

                                Button {
                                    captureMonitor.copyToPasteboard(item)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(captureActionForeground(.copy, for: item))
                                        .scaleEffect(captureActionScale(.copy, for: item))
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(captureActionBackground(.copy, for: item)))
                                        .animation(.easeInOut(duration: 0.12), value: captureActionScale(.copy, for: item))
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    setCaptureHover(hovering, action: .copy, for: item)
                                }

                                Button {
                                    captureMonitor.saveToDesktop(item)
                                } label: {
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundStyle(captureActionForeground(.save, for: item))
                                        .scaleEffect(captureActionScale(.save, for: item))
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(captureActionBackground(.save, for: item)))
                                        .animation(.easeInOut(duration: 0.12), value: captureActionScale(.save, for: item))
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    setCaptureHover(hovering, action: .save, for: item)
                                }

                                Button {
                                    captureMonitor.remove(item)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(captureActionForeground(.delete, for: item))
                                        .scaleEffect(captureActionScale(.delete, for: item))
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(captureActionBackground(.delete, for: item)))
                                        .animation(.easeInOut(duration: 0.12), value: captureActionScale(.delete, for: item))
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    setCaptureHover(hovering, action: .delete, for: item)
                                }
                            }
                            .padding(.vertical, 2)
                        }
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
                    .background(Circle().fill(isHoveringAddButton ? Color.blue.opacity(0.2) : .white))
                    .scaleEffect(isHoveringAddButton ? 1.22 : 1.0)
                    .shadow(radius: 2, y: 1)
                    .animation(.easeInOut(duration: 0.12), value: isHoveringAddButton)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringAddButton = hovering
            }
            .padding(12)
        }
        .background(.clear)
        .background(WindowConfigurator(totalRows: totalRows))
    }

    @ViewBuilder
    private func previewView(for item: CaptureItem) -> some View {
        if let image = item.thumbnail {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if item.kind == .video {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.15))
                Image(systemName: "video.fill")
                    .foregroundStyle(.black.opacity(0.8))
            }
            .frame(width: 92, height: 56)
        }
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

    private func setCaptureHover(_ hovering: Bool, action: CaptureAction, for item: CaptureItem) {
        let key = CaptureActionKey(itemID: item.id, action: action)
        if hovering {
            _ = hoveredCaptureActions.insert(key)
        } else {
            _ = hoveredCaptureActions.remove(key)
        }
    }

    private func isCaptureHovering(_ action: CaptureAction, for item: CaptureItem) -> Bool {
        hoveredCaptureActions.contains(CaptureActionKey(itemID: item.id, action: action))
    }

    private func captureActionScale(_ action: CaptureAction, for item: CaptureItem) -> CGFloat {
        isCaptureHovering(action, for: item) ? 1.22 : 1.0
    }

    private func captureActionForeground(_ action: CaptureAction, for item: CaptureItem) -> Color {
        if isCaptureHovering(action, for: item) {
            switch action {
            case .copy: return .blue
            case .save: return .green
            case .delete: return .red
            }
        }

        if action == .delete {
            return .red.opacity(0.88)
        }
        return .black
    }

    private func captureActionBackground(_ action: CaptureAction, for item: CaptureItem) -> Color {
        if isCaptureHovering(action, for: item) {
            switch action {
            case .copy: return Color.blue.opacity(0.12)
            case .save: return Color.green.opacity(0.12)
            case .delete: return Color.red.opacity(0.12)
            }
        }
        return Color.white.opacity(0.92)
    }

    private func isTaskDeleteHovered(_ task: TaskItem) -> Bool {
        hoveredTaskDeleteIDs.contains(task.persistentModelID)
    }

    private func setTaskDeleteHover(_ hovering: Bool, for task: TaskItem) {
        let id = task.persistentModelID
        if hovering {
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

enum CaptureKind {
    case image
    case video
}

struct CaptureItem: Identifiable {
    let id = UUID()
    let kind: CaptureKind
    let sourcePath: String
    let fileDate: Date
    let thumbnail: NSImage?
    let stagedURL: URL?
}

@MainActor
final class CaptureMonitor: ObservableObject {
    @Published var items: [CaptureItem] = []

    private var processedPaths: Set<String> = []
    private var timer: Timer?
    private let fm = FileManager.default
    private let stagingDirectory: URL

    init() {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        stagingDirectory = base.appendingPathComponent("TaskAppCaptureStaging", isDirectory: true)
        try? fm.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        seedExisting()
        start()
    }

    deinit {
        timer?.invalidate()
    }

    func remove(_ item: CaptureItem) {
        if let stagedURL = item.stagedURL {
            try? fm.removeItem(at: stagedURL)
        }
        items.removeAll { $0.id == item.id }
    }

    func copyToPasteboard(_ item: CaptureItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.kind {
        case .image:
            if let image = item.thumbnail {
                _ = pb.writeObjects([image])
            }
        case .video:
            if let url = item.stagedURL {
                _ = pb.writeObjects([url as NSURL])
            }
        }
    }

    func saveToDesktop(_ item: CaptureItem) {
        let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first!

        switch item.kind {
        case .image:
            guard
                let image = item.thumbnail,
                let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff),
                let pngData = bitmap.representation(using: .png, properties: [:])
            else { return }

            let base = URL(fileURLWithPath: item.sourcePath).deletingPathExtension().lastPathComponent
            let name = base.isEmpty ? "Screenshot" : base
            let target = uniqueURL(in: desktop, baseName: name, ext: "png")
            try? pngData.write(to: target, options: .atomic)

        case .video:
            guard let stagedURL = item.stagedURL else { return }
            let base = URL(fileURLWithPath: item.sourcePath).deletingPathExtension().lastPathComponent
            let ext = stagedURL.pathExtension.isEmpty ? "mov" : stagedURL.pathExtension
            let name = base.isEmpty ? "Screen Recording" : base
            let target = uniqueURL(in: desktop, baseName: name, ext: ext)
            try? fm.copyItem(at: stagedURL, to: target)
        }
    }

    private func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scan()
            }
        }
        timer?.tolerance = 0.1
    }

    private func captureDirectory() -> URL {
        if let raw = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture")?["location"] as? String {
            let expanded = NSString(string: raw).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return fm.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    private func seedExisting() {
        let dir = captureDirectory()
        guard let urls = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in urls where isCaptureFile(url) {
            processedPaths.insert(url.path)
        }
    }

    private func scan() {
        let dir = captureDirectory()

        guard let urls = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let candidates = urls
            .filter { isCaptureFile($0) && !processedPaths.contains($0.path) }
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
        let ext = url.pathExtension.lowercased()
        let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()

        if isImageExt(ext) {
            processImage(url: url, created: created)
            return
        }

        if isVideoExt(ext) {
            processVideo(url: url, created: created)
            return
        }
    }

    private func processImage(url: URL, created: Date) {
        var image: NSImage?
        for _ in 0..<8 {
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

        items.insert(
            CaptureItem(
                kind: .image,
                sourcePath: url.path,
                fileDate: created,
                thumbnail: image,
                stagedURL: nil
            ),
            at: 0
        )

        try? fm.removeItem(at: url)
        bringAppToFront()
    }

    private func processVideo(url: URL, created: Date) {
        var data: Data?
        for _ in 0..<10 {
            if let loaded = try? Data(contentsOf: url), !loaded.isEmpty {
                data = loaded
                break
            }
            Thread.sleep(forTimeInterval: 0.12)
        }
        guard let data else { return }

        processedPaths.insert(url.path)

        let stagedURL = stagingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)

        do {
            try data.write(to: stagedURL, options: .atomic)
        } catch {
            return
        }

        let thumbnail = makeVideoThumbnail(from: stagedURL)

        let pb = NSPasteboard.general
        pb.clearContents()
        _ = pb.writeObjects([stagedURL as NSURL])

        items.insert(
            CaptureItem(
                kind: .video,
                sourcePath: url.path,
                fileDate: created,
                thumbnail: thumbnail,
                stagedURL: stagedURL
            ),
            at: 0
        )

        try? fm.removeItem(at: url)
        bringAppToFront()
    }

    private func makeVideoThumbnail(from url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 0.2, preferredTimescale: 600), actualTime: nil)
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            return NSImage(cgImage: cgImage, size: size)
        } catch {
            return nil
        }
    }

    private func isCaptureFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        let isMedia = isImageExt(ext) || isVideoExt(ext)
        let looksLikeCapture =
            name.contains("screenshot") ||
            name.contains("screen shot") ||
            name.contains("screen recording") ||
            name.contains("recording") ||
            name.contains("capture") ||
            name.contains("スクリーンショット") ||
            name.contains("スクリーン") ||
            name.contains("録画") ||
            name.contains("画面")

        return isMedia && looksLikeCapture
    }

    private func isImageExt(_ ext: String) -> Bool {
        ["png", "jpg", "jpeg", "heic", "tiff"].contains(ext)
    }

    private func isVideoExt(_ ext: String) -> Bool {
        ["mov", "mp4", "m4v"].contains(ext)
    }

    private func uniqueURL(in directory: URL, baseName: String, ext: String) -> URL {
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
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        }
    }
}
