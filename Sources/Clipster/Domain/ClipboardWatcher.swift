import Foundation
import AppKit

final class ClipboardWatcher {
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general
    private let repository: ItemRepository
    private let deduplicator: Deduplicator
    var onNewItem: ((ClipItem) -> Void)?

    init(_ repository: ItemRepository, _ deduplicator: Deduplicator) {
        self.repository = repository
        self.deduplicator = deduplicator
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(interval: TimeInterval = 0.5) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.check()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        readAndStore()
    }

    private func readAndStore() {
        if let item = readText() {
            store(item)
            return
        }
        if let item = readImage() {
            store(item)
            return
        }
        if let item = readFileURLs() {
            store(item)
        }
    }

    private func readText() -> ClipItem? {
        guard let str = pasteboard.readObjects(forClasses: [NSString.self], options: nil)?.first as? String else {
            return nil
        }
        let trimmed = str.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let category = ContentClassifier.classify(trimmed)
        let hash = ContentClassifier.sha256(trimmed)
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return ClipItem(
            content: trimmed,
            contentHash: hash,
            category: category,
            mimeType: "text/plain",
            sizeBytes: Int64(trimmed.utf8.count),
            appSource: app
        )
    }

    private func readImage() -> ClipItem? {
        guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
              let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        let dir = imageStorageDir()
        let filename = "img_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 0..<10000)).png"
        let path = dir.appendingPathComponent(filename)
        try? pngData.write(to: path)
        let hash = ContentClassifier.sha256("image:\(filename)")
        return ClipItem(
            content: filename,
            contentHash: hash,
            category: .image,
            mimeType: "image/png",
            payloadURL: path.path,
            sizeBytes: Int64(pngData.count)
        )
    }

    private func readFileURLs() -> ClipItem? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first else {
            return nil
        }
        let isDir = (try? url.resourceValues(forKeys: [URLResourceKey.isDirectoryKey]))?.isDirectory ?? false
        let size = (try? url.resourceValues(forKeys: [URLResourceKey.fileSizeKey]))?.fileSize ?? 0
        let hash = ContentClassifier.sha256("file:\(url.path)")
        return ClipItem(
            content: url.lastPathComponent,
            contentHash: hash,
            category: .text,
            mimeType: isDir ? "public.folder" : "public.file",
            payloadURL: url.path,
            sizeBytes: Int64(size)
        )
    }

    private func store(_ item: ClipItem) {
        guard let fresh = deduplicator.process(item) else { return }
        if let id = repository.insert(fresh) {
            var saved = fresh
            saved.id = id
            DispatchQueue.main.async { [weak self] in
                self?.onNewItem?(saved)
            }
        }
    }

    private func imageStorageDir() -> URL {
        let fm = FileManager.default
        let appSupport = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("Clipster/images")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
