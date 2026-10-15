import AppKit
import CB21Core

/// Renders Detail pane pictures off the main thread and remembers the latest few.
actor PreviewCache {
    static let shared = PreviewCache()

    private struct Entry { let image: NSImage? }
    private var entries: [UUID: Entry] = [:]
    private var order: [UUID] = []
    private let capacity = 30

    func image(for clip: Clip) async -> NSImage? {
        if let hit = entries[clip.id] {
            return hit.image
        }
        let cgImage = await PreviewRenderer.render(clip)
        let image = cgImage.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
        entries[clip.id] = Entry(image: image)
        order.append(clip.id)
        if order.count > capacity {
            entries.removeValue(forKey: order.removeFirst())
        }
        return image
    }

    /// Forget a deleted Clip's picture.
    func forget(_ id: UUID) {
        entries.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }
}
