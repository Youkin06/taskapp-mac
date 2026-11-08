import SwiftUI
import AppKit
import AVFoundation
import CoreServices

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

    @ObservedObject var captureMonitor: CaptureMonitor

    @State private var hoveredCaptureActions: Set<CaptureActionKey> = []
    @State private var selectedCaptureIDs: Set<UUID> = []

    private var selectedCaptures: [CaptureItem] {
        captureMonitor.items.filter { selectedCaptureIDs.contains($0.id) }
    }

    private var captureListMaxHeight: CGFloat {
        guard let screenHeight = NSScreen.main?.visibleFrame.height else { return 720 }
        return min(720, max(360, screenHeight - 220))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                Text("Screen Copy")
                    .font(.headline)
                Spacer()
                if !captureMonitor.items.isEmpty {
                    Text("\(captureMonitor.items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            if captureMonitor.items.isEmpty {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text("監視中: スクリーンショット / 録画を待機")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 72)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(captureMonitor.items) { item in
                            captureRow(for: item)
                            if item.id != captureMonitor.items.last?.id {
                                Divider()
                                    .padding(.leading, 118)
                            }
                        }
                    }
                }
                .frame(maxHeight: captureListMaxHeight)
            }

            Divider()

            HStack(spacing: 0) {
                Toggle(isOn: $captureMonitor.keepOriginals) {
                    Text("元ファイルを残す")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                .help("オンのあいだは、クリップボードにコピーしたあとも元ファイルを保存先に残します")

                Spacer()

                Toggle(isOn: $captureMonitor.copyFilePaths) {
                    Text("パスも一緒にコピー")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                .help("オンのあいだは、ターミナルやコードエディタに貼り付けるとファイルのパスが入ります。LINE などほかのアプリには画像だけが貼り付けられます")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)

            Divider()

            HStack {
                if !captureMonitor.items.isEmpty {
                    Button {
                        captureMonitor.clear()
                        selectedCaptureIDs.removeAll()
                    } label: {
                        Label("消去", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if !selectedCaptureIDs.isEmpty {
                    Text("\(selectedCaptureIDs.count)選択中")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        captureMonitor.copyToPasteboard(selectedCaptures)
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)

                    Button {
                        selectedCaptureIDs.removeAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("選択を解除")
                }

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("終了", systemImage: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 380)
        .onChange(of: captureMonitor.items.map(\.id)) { _, ids in
            selectedCaptureIDs.formIntersection(Set(ids))
        }
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

    private func isCaptureSelected(_ item: CaptureItem) -> Bool {
        selectedCaptureIDs.contains(item.id)
    }

    private func toggleCaptureSelection(_ item: CaptureItem) {
        if selectedCaptureIDs.contains(item.id) {
            selectedCaptureIDs.remove(item.id)
        } else {
            selectedCaptureIDs.insert(item.id)
        }
    }

    private func capturesToCopy(triggeredBy item: CaptureItem) -> [CaptureItem] {
        selectedCaptures.isEmpty ? [item] : selectedCaptures
    }

    private func captureRow(for item: CaptureItem) -> some View {
        HStack(spacing: 10) {
            selectablePreview(for: item)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.kind == .video ? "動画を一時保存中" : "画像をコピー済み")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.fileDate, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                actionButton(.copy, systemName: "doc.on.doc", help: copyHelpText(for: item), for: item) {
                    captureMonitor.copyToPasteboard(capturesToCopy(triggeredBy: item))
                }

                actionButton(.save, systemName: "square.and.arrow.down", help: "デスクトップへ保存", for: item) {
                    captureMonitor.saveToDesktop(item)
                }

                actionButton(.delete, systemName: "trash", help: "一覧から削除", for: item) {
                    captureMonitor.remove(item)
                    selectedCaptureIDs.remove(item.id)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isCaptureSelected(item) ? Color.blue.opacity(0.06) : Color.clear)
    }

    private func copyHelpText(for item: CaptureItem) -> String {
        let count = capturesToCopy(triggeredBy: item).count
        return count > 1 ? "\(count)件をクリップボードへコピー" : "クリップボードへコピー"
    }

    private func selectablePreview(for item: CaptureItem) -> some View {
        Button {
            toggleCaptureSelection(item)
        } label: {
            previewView(for: item)
                .overlay(alignment: .topLeading) {
                    Image(systemName: isCaptureSelected(item) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            isCaptureSelected(item) ? Color.white : Color.black.opacity(0.72),
                            isCaptureSelected(item) ? Color.blue : Color.white.opacity(0.92)
                        )
                        .padding(5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCaptureSelected(item) ? Color.blue : Color.clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .help(isCaptureSelected(item) ? "選択を解除" : "選択")
    }

    @ViewBuilder
    private func previewView(for item: CaptureItem) -> some View {
        if let image = item.thumbnail {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
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

    private func actionButton(
        _ action: CaptureAction,
        systemName: String,
        help: String,
        for item: CaptureItem,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Image(systemName: systemName)
                .foregroundStyle(captureActionForeground(action, for: item))
                .scaleEffect(captureActionScale(action, for: item))
                .frame(width: 26, height: 26)
                .background(Circle().fill(captureActionBackground(action, for: item)))
                .animation(.easeInOut(duration: 0.12), value: captureActionScale(action, for: item))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            setCaptureHover(hovering, action: action, for: item)
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
    private struct PendingCapture {
        var fileSize: Int64
        var modifiedAt: Date
        var stableSince: Date
    }

    private struct CaptureSnapshot {
        let fileSize: Int64
        let modifiedAt: Date
        let createdAt: Date
        let kind: CaptureKind
    }

    private struct CaptureHandling {
        let shouldTrack: Bool
        let shouldRemoveSource: Bool
    }

    private static let keepOriginalsKey = "keepOriginalFiles"
    private static let copyFilePathsKey = "copyFilePaths"
    private static let stagedFileLifetime: TimeInterval = 7 * 24 * 60 * 60

    private static let stagingNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    @Published var items: [CaptureItem] = []

    /// When on, captures are copied to the clipboard but left in the screenshot
    /// folder. Off by default, so the existing behaviour is unchanged.
    @Published var keepOriginals: Bool {
        didSet {
            UserDefaults.standard.set(keepOriginals, forKey: Self.keepOriginalsKey)
        }
    }

    /// When on, the clipboard also carries the staged file and its path as text
    /// while a terminal or code editor (e.g. Claude Code) is in front. Other apps
    /// get the image alone. On by default.
    @Published var copyFilePaths: Bool {
        didSet {
            UserDefaults.standard.set(copyFilePaths, forKey: Self.copyFilePathsKey)
        }
    }

    private var processedPaths: Set<String> = []
    private var pendingCaptures: [String: PendingCapture] = [:]
    private var timer: DispatchSourceTimer?
    private var activationObserver: NSObjectProtocol?
    private var lastCopiedItems: [CaptureItem] = []
    private var lastCopyChangeCount = -1
    private var lastCopyIncludesPaths = false
    private let fm = FileManager.default
    private let stagingDirectory: URL
    private let launchedAt = Date()

    init() {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        stagingDirectory = base.appendingPathComponent("ClipShotCaptureStaging", isDirectory: true)
        try? fm.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        keepOriginals = UserDefaults.standard.bool(forKey: Self.keepOriginalsKey)
        copyFilePaths = UserDefaults.standard.object(forKey: Self.copyFilePathsKey) as? Bool ?? true

        removeExpiredStagedFiles()
        seedExisting()
        start()
        observeAppActivation()
    }

    deinit {
        timer?.cancel()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    func remove(_ item: CaptureItem) {
        if let stagedURL = item.stagedURL {
            try? fm.removeItem(at: stagedURL)
        }
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        for item in items {
            if let stagedURL = item.stagedURL {
                try? fm.removeItem(at: stagedURL)
            }
        }
        items.removeAll()
    }

    func copyToPasteboard(_ items: [CaptureItem]) {
        lastCopiedItems = items
        writePasteboard(for: NSWorkspace.shared.frontmostApplication)
    }

    /// Apps that paste the path text. Elsewhere the clipboard carries only the
    /// image, so chat apps like LINE paste it at once instead of asking
    /// whether to paste text or image.
    private static let pathPasteBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "org.alacritty",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.exafunction.windsurf",
        "dev.zed.Zed",
    ]

    private func includesPaths(for app: NSRunningApplication?) -> Bool {
        guard copyFilePaths else { return false }
        // While ClipShot itself is in front the target is unknown; the
        // clipboard is rewritten when the next app becomes active.
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return true }
        return app.bundleIdentifier.map(Self.pathPasteBundleIDs.contains) ?? false
    }

    private func writePasteboard(for app: NSRunningApplication?) {
        let withPaths = includesPaths(for: app)
        let pasteboardItems = lastCopiedItems.compactMap { makePasteboardItem(for: $0, withPaths: withPaths) }
        guard !pasteboardItems.isEmpty else { return }

        // Terminals read only the first item's text, so it carries every path.
        let paths = withPaths ? lastCopiedItems.compactMap { $0.stagedURL?.path } : []
        if !paths.isEmpty {
            pasteboardItems[0].setString(paths.joined(separator: " "), forType: .string)
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        _ = pb.writeObjects(pasteboardItems)
        lastCopyChangeCount = pb.changeCount
        lastCopyIncludesPaths = withPaths
    }

    private func observeAppActivation() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                self?.handleActivation(of: app)
            }
        }
    }

    private func handleActivation(of app: NSRunningApplication?) {
        // Only touch the clipboard while it still holds what ClipShot copied.
        guard !lastCopiedItems.isEmpty, NSPasteboard.general.changeCount == lastCopyChangeCount else { return }
        guard includesPaths(for: app) != lastCopyIncludesPaths else { return }
        writePasteboard(for: app)
    }

    private func makePasteboardItem(for item: CaptureItem, withPaths: Bool) -> NSPasteboardItem? {
        let pasteboardItem = NSPasteboardItem()
        var hasContent = false

        if item.kind == .image, let tiff = item.thumbnail?.tiffRepresentation {
            if let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                pasteboardItem.setData(png, forType: .png)
            }
            pasteboardItem.setData(tiff, forType: .tiff)
            hasContent = true
        }

        if let stagedURL = item.stagedURL, item.kind == .video || withPaths {
            pasteboardItem.setString(stagedURL.absoluteString, forType: .fileURL)
            hasContent = true
        }

        return hasContent ? pasteboardItem : nil
    }

    func copyToPasteboard(_ item: CaptureItem) {
        copyToPasteboard([item])
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
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(350), leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.scan()
            }
        }
        self.timer = timer
        timer.resume()
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
        for url in urls where captureKind(for: url) != nil {
            processedPaths.insert(url.path)
        }
    }

    private func scan() {
        let dir = captureDirectory()
        let now = Date()
        let resourceKeys: Set<URLResourceKey> = [
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ]

        guard let urls = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else { return }

        var activeCandidatePaths: Set<String> = []
        let candidates = urls.compactMap { url -> (url: URL, snapshot: CaptureSnapshot, shouldRemoveSource: Bool)? in
            guard !processedPaths.contains(url.path),
                  let snapshot = captureSnapshot(for: url, resourceKeys: resourceKeys)
            else { return nil }

            let handling = captureHandling(for: url, snapshot: snapshot)
            guard handling.shouldTrack else { return nil }

            activeCandidatePaths.insert(url.path)
            return (url, snapshot, handling.shouldRemoveSource)
        }
        .sorted { lhs, rhs in
            lhs.snapshot.createdAt > rhs.snapshot.createdAt
        }

        pendingCaptures = pendingCaptures.filter { activeCandidatePaths.contains($0.key) }

        for candidate in candidates {
            let path = candidate.url.path
            guard isStable(candidate.snapshot, at: now, forPath: path) else { continue }
            if process(
                url: candidate.url,
                kind: candidate.snapshot.kind,
                created: candidate.snapshot.createdAt,
                shouldRemoveSource: candidate.shouldRemoveSource
            ) {
                processedPaths.insert(path)
                pendingCaptures.removeValue(forKey: path)
            }
        }
    }

    private func captureSnapshot(for url: URL, resourceKeys: Set<URLResourceKey>) -> CaptureSnapshot? {
        guard let kind = captureKind(for: url),
              let values = try? url.resourceValues(forKeys: resourceKeys),
              values.isRegularFile != false
        else { return nil }

        let fileSize = Int64(values.fileSize ?? 0)
        guard fileSize > 0 else { return nil }

        let createdAt = values.creationDate ?? Date()
        let modifiedAt = values.contentModificationDate ?? createdAt

        return CaptureSnapshot(
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            createdAt: createdAt,
            kind: kind
        )
    }

    private func captureHandling(for url: URL, snapshot: CaptureSnapshot) -> CaptureHandling {
        if hasScreenCaptureMetadata(url) || hasCaptureName(url) {
            return CaptureHandling(shouldTrack: true, shouldRemoveSource: !keepOriginals)
        }

        // If the user customized macOS screenshot names, the file may not contain
        // "screenshot" or localized equivalents. Existing media is seeded on launch,
        // so only new media files in the configured screenshot directory reach here.
        // These fallback matches are copied but not removed, which avoids deleting
        // unrelated images or videos saved to Desktop.
        if snapshot.createdAt >= launchedAt.addingTimeInterval(-2) {
            return CaptureHandling(shouldTrack: true, shouldRemoveSource: false)
        }

        return CaptureHandling(shouldTrack: false, shouldRemoveSource: false)
    }

    private func isStable(_ snapshot: CaptureSnapshot, at now: Date, forPath path: String) -> Bool {
        let requiredStableDuration = stableDuration(for: snapshot.kind)

        guard var pending = pendingCaptures[path] else {
            pendingCaptures[path] = PendingCapture(
                fileSize: snapshot.fileSize,
                modifiedAt: snapshot.modifiedAt,
                stableSince: now
            )
            return false
        }

        if pending.fileSize != snapshot.fileSize || pending.modifiedAt != snapshot.modifiedAt {
            pending.fileSize = snapshot.fileSize
            pending.modifiedAt = snapshot.modifiedAt
            pending.stableSince = now
            pendingCaptures[path] = pending
            return false
        }

        pendingCaptures[path] = pending
        return now.timeIntervalSince(pending.stableSince) >= requiredStableDuration
    }

    private func stableDuration(for kind: CaptureKind) -> TimeInterval {
        switch kind {
        case .image:
            return 0.8
        case .video:
            return 2.5
        }
    }

    private func process(url: URL, kind: CaptureKind, created: Date, shouldRemoveSource: Bool) -> Bool {
        switch kind {
        case .image:
            return processImage(url: url, created: created, shouldRemoveSource: shouldRemoveSource)
        case .video:
            return processVideo(url: url, created: created, shouldRemoveSource: shouldRemoveSource)
        }
    }

    private func processImage(url: URL, created: Date, shouldRemoveSource: Bool) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let image = NSImage(data: data)
        else { return false }

        // Staged so the clipboard can offer a path that outlives the source file.
        let stagedURL = makeStagingURL(for: url, created: created)
        let didStage = (try? fm.copyItem(at: url, to: stagedURL)) != nil

        let item = CaptureItem(
            kind: .image,
            sourcePath: url.path,
            fileDate: created,
            thumbnail: image,
            stagedURL: didStage ? stagedURL : nil
        )
        items.insert(item, at: 0)
        copyToPasteboard(item)

        if shouldRemoveSource {
            try? fm.removeItem(at: url)
        }
        return true
    }

    private func processVideo(url: URL, created: Date, shouldRemoveSource: Bool) -> Bool {
        let stagedURL = makeStagingURL(for: url, created: created)

        do {
            try fm.copyItem(at: url, to: stagedURL)
        } catch {
            return false
        }

        let thumbnail = makeVideoThumbnail(from: stagedURL)

        let item = CaptureItem(
            kind: .video,
            sourcePath: url.path,
            fileDate: created,
            thumbnail: thumbnail,
            stagedURL: stagedURL
        )
        items.insert(item, at: 0)
        copyToPasteboard(item)

        if shouldRemoveSource {
            try? fm.removeItem(at: url)
        }
        return true
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

    private func captureKind(for url: URL) -> CaptureKind? {
        let ext = url.pathExtension.lowercased()
        if isImageExt(ext) { return .image }
        if isVideoExt(ext) { return .video }
        return nil
    }

    private func hasCaptureName(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name.contains("screenshot") ||
            name.contains("screen shot") ||
            name.contains("screen recording") ||
            name.contains("recording") ||
            name.contains("capture") ||
            name.contains("スクリーンショット") ||
            name.contains("スクリーン") ||
            name.contains("録画") ||
            name.contains("画面")
    }

    private func hasScreenCaptureMetadata(_ url: URL) -> Bool {
        guard let item = MDItemCreate(kCFAllocatorDefault, url.path as CFString) else { return false }

        if let value = MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? NSNumber,
           value.boolValue {
            return true
        }

        return MDItemCopyAttribute(item, "kMDItemScreenCaptureType" as CFString) != nil
    }

    private func isImageExt(_ ext: String) -> Bool {
        ["png", "jpg", "jpeg", "heic", "tiff"].contains(ext)
    }

    private func isVideoExt(_ ext: String) -> Bool {
        ["mov", "mp4", "m4v"].contains(ext)
    }

    /// Names avoid spaces so a pasted path works in a terminal without quoting.
    private func makeStagingURL(for source: URL, created: Date) -> URL {
        let ext = source.pathExtension.lowercased()
        let baseName = "clipshot-\(Self.stagingNameFormatter.string(from: created))"
        var candidate = stagingDirectory.appendingPathComponent(baseName).appendingPathExtension(ext)
        var index = 1
        while fm.fileExists(atPath: candidate.path) {
            candidate = stagingDirectory.appendingPathComponent("\(baseName)-\(index)").appendingPathExtension(ext)
            index += 1
        }
        return candidate
    }

    /// Staged files outlive the in-memory list, so old ones are pruned on launch.
    /// They are kept for a while because pasted paths may still be read later.
    private func removeExpiredStagedFiles() {
        guard let urls = try? fm.contentsOfDirectory(
            at: stagingDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-Self.stagedFileLifetime)
        for url in urls {
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modifiedAt, modifiedAt < cutoff {
                try? fm.removeItem(at: url)
            }
        }
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

}
