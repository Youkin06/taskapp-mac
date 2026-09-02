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

    @Published var items: [CaptureItem] = []

    /// When on, captures are copied to the clipboard but left in the screenshot
    /// folder. Off by default, so the existing behaviour is unchanged.
    @Published var keepOriginals: Bool {
        didSet {
            UserDefaults.standard.set(keepOriginals, forKey: Self.keepOriginalsKey)
        }
    }

    private var processedPaths: Set<String> = []
    private var pendingCaptures: [String: PendingCapture] = [:]
    private var timer: DispatchSourceTimer?
    private let fm = FileManager.default
    private let stagingDirectory: URL
    private let launchedAt = Date()

    init() {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        stagingDirectory = base.appendingPathComponent("ClipShotCaptureStaging", isDirectory: true)
        try? fm.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        keepOriginals = UserDefaults.standard.bool(forKey: Self.keepOriginalsKey)

        seedExisting()
        start()
    }

    deinit {
        timer?.cancel()
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
        let objects: [NSPasteboardWriting] = items.compactMap { item in
            switch item.kind {
            case .image:
                return item.thumbnail
            case .video:
                guard let url = item.stagedURL else { return nil }
                return url as NSURL
            }
        }

        guard !objects.isEmpty else { return }

        let pb = NSPasteboard.general
        pb.clearContents()
        _ = pb.writeObjects(objects)
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

        if shouldRemoveSource {
            try? fm.removeItem(at: url)
        }
        return true
    }

    private func processVideo(url: URL, created: Date, shouldRemoveSource: Bool) -> Bool {
        let stagedURL = stagingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)

        do {
            try fm.copyItem(at: url, to: stagedURL)
        } catch {
            return false
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
