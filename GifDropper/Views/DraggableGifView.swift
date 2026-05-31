import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - NSViewRepresentable bridge

struct DraggableGifView: NSViewRepresentable {
    let gif: Gif
    let imageData: Data?
    let isHovered: Bool

    func makeNSView(context: Context) -> DragGifNSView {
        DragGifNSView()
    }

    func updateNSView(_ nsView: DragGifNSView, context: Context) {
        nsView.gif = gif
        nsView.setImageData(imageData)
        if isHovered { nsView.prefetchIfNeeded() }
    }
}

// MARK: - AppKit drag view

final class DragGifNSView: NSView {
    var gif: Gif?

    private let imageView = NSImageView()
    private var mouseDownEvent: NSEvent?

    // Set on main thread in mouseDragged; read on promise queue in delegate methods.
    nonisolated(unsafe) private var promiseGifURL: URL?
    nonisolated(unsafe) private var promiseName: String = "animation.gif"

    // Cache: gif.id → local temp file URL (already on disk)
    private static let cache = NSCache<NSString, NSURL>()

    private static let promiseQueue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        q.name = "com.lavi.GifDropper.filePromise"
        return q
    }()

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        imageView.animates = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func setImageData(_ data: Data?) {
        if let data, let image = NSImage(data: data) {
            image.cacheMode = .never
            imageView.image = image
        } else {
            imageView.image = nil
        }
    }

    // Start downloading the full GIF to disk on hover so it's ready before drag.
    func prefetchIfNeeded() {
        guard let gif else { return }
        let key = gif.id as NSString
        if let cached = Self.cache.object(forKey: key),
           FileManager.default.fileExists(atPath: cached.path!) { return }
        Self.cache.removeObject(forKey: key)
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: gif.gifURL) else { return }
            let url = Self.tempURL(for: gif)
            guard (try? data.write(to: url)) != nil else { return }
            Self.cache.setObject(url as NSURL, forKey: key)
        }
    }

    private static func tempURL(for gif: Gif) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gifdropper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = String(gif.description.prefix(40)).replacingOccurrences(of: "/", with: "-")
        return dir.appendingPathComponent("\(gif.id)_\(safe).gif")
    }

    // MARK: - Mouse events

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let gif, let downEvent = mouseDownEvent else { return }
        mouseDownEvent = nil

        // Capture for the promise callback (main thread write, background read — safe
        // because write always happens before the promise queue reads it).
        promiseGifURL = gif.gifURL
        let safe = String(gif.description.prefix(40)).replacingOccurrences(of: "/", with: "-")
        promiseName = "\(safe).gif"

        // Freeze popover so it can't auto-dismiss while we're dragging to another app.
        NotificationCenter.default.post(name: .gifDragBegan, object: nil)

        // If the full GIF is already on disk, hand Slack a concrete public.file-url.
        // Otherwise fall back to a file promise (Slack will wait for the download).
        let key = gif.id as NSString
        let pasteboardWriter: NSPasteboardWriting
        if let cachedURL = Self.cache.object(forKey: key),
           FileManager.default.fileExists(atPath: cachedURL.path!) {
            pasteboardWriter = cachedURL
        } else {
            pasteboardWriter = NSFilePromiseProvider(fileType: UTType.gif.identifier, delegate: self)
        }

        let item = NSDraggingItem(pasteboardWriter: pasteboardWriter)
        let thumb = imageView.image ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
        item.setDraggingFrame(NSRect(origin: .zero, size: NSSize(width: 120, height: 120)), contents: thumb)

        beginDraggingSession(with: [item], event: downEvent, source: self)
    }
}

// MARK: - NSDraggingSource

extension DragGifNSView: NSDraggingSource {
    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation { .copy }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        NotificationCenter.default.post(name: .gifDragEnded, object: nil)
    }
}

// MARK: - NSFilePromiseProviderDelegate (fallback path)

extension DragGifNSView: NSFilePromiseProviderDelegate {
    nonisolated func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String { promiseName }

    nonisolated func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let gifURL = promiseGifURL else {
            completionHandler(NSError(domain: "GifDropper", code: 1))
            return
        }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: gifURL)
                try data.write(to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    nonisolated func operationQueue(
        for filePromiseProvider: NSFilePromiseProvider
    ) -> OperationQueue { DragGifNSView.promiseQueue }
}

// MARK: - Notification names

extension Notification.Name {
    static let gifDragBegan = Notification.Name("gifDragBegan")
    static let gifDragEnded = Notification.Name("gifDragEnded")
}
