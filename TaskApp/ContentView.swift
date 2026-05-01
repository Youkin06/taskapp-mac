import SwiftUI
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

    @ObservedObject var captureMonitor: CaptureMonitor

    @State private var hoveredCaptureActions: Set<CaptureActionKey> = []

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
                .frame(maxHeight: 360)
            }

            Divider()

            HStack {
                if !captureMonitor.items.isEmpty {
                    Button {
                        captureMonitor.clear()
                    } label: {
                        Label("消去", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

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

    private func captureRow(for item: CaptureItem) -> some View {
        HStack(spacing: 10) {
            previewView(for: item)

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
                actionButton(.copy, systemName: "doc.on.doc", help: "クリップボードへコピー", for: item) {
                    captureMonitor.copyToPasteboard(item)
                }

                actionButton(.save, systemName: "square.and.arrow.down", help: "デスクトップへ保存", for: item) {
                    captureMonitor.saveToDesktop(item)
                }

                actionButton(.delete, systemName: "trash", help: "一覧から削除", for: item) {
                    captureMonitor.remove(item)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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

    func clear() {
        for item in items {
            if let stagedURL = item.stagedURL {
                try? fm.removeItem(at: stagedURL)
            }
        }
        items.removeAll()
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

}
