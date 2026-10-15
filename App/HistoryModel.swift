import AppKit
import CB21Core
import Observation

/// What the menu shows: the most recently used Clips with their previews.
@MainActor
@Observable
final class HistoryModel {
    struct Row: Identifiable {
        let id: UUID
        let preview: ClipPreview
        let thumbnail: NSImage?
    }

    static let menuLimit = 10

    private(set) var rows: [Row] = []
    private(set) var pasteboardAccessDenied = false

    func setPasteboardAccessDenied(_ denied: Bool) {
        if pasteboardAccessDenied != denied { pasteboardAccessDenied = denied }
    }

    func refresh(from store: ClipStore) async {
        guard let clips = try? await store.list() else { return }
        rows = clips.prefix(Self.menuLimit).map { clip in
            Row(id: clip.id, preview: clip.preview, thumbnail: Self.thumbnail(for: clip))
        }
    }

    private static func thumbnail(for clip: Clip) -> NSImage? {
        guard clip.preview == .image,
              let image = NSImage(data: clip.preferred.data) else { return nil }
        let size = NSSize(width: 18, height: 18)
        let thumb = NSImage(size: size)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        thumb.unlockFocus()
        return thumb
    }
}
