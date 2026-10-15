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

    /// Every Clip in History, most recently used first.
    private(set) var rows: [Row] = []
    private var thumbnails: [UUID: NSImage] = [:]

    /// The latest Clips, as shown in the menu.
    var menuRows: [Row] { Array(rows.prefix(Self.menuLimit)) }
    private(set) var pasteboardAccessDenied = false
    private(set) var isPaused = false

    func setPaused(_ paused: Bool) {
        if isPaused != paused { isPaused = paused }
    }

    /// One-time messages shown at the top of the menu until dismissed.
    enum Notice: Hashable {
        case clipTooLarge
        case databaseRecovered
    }

    private(set) var notices: [Notice] = []

    func post(_ notice: Notice) {
        if !notices.contains(notice) { notices.append(notice) }
    }

    func dismiss(_ notice: Notice) {
        notices.removeAll { $0 == notice }
    }

    func setPasteboardAccessDenied(_ denied: Bool) {
        if pasteboardAccessDenied != denied { pasteboardAccessDenied = denied }
    }

    func refresh(from store: ClipStore) async {
        guard let clips = try? await store.list() else { return }
        let live = Set(clips.map(\.id))
        thumbnails = thumbnails.filter { live.contains($0.key) }
        rows = clips.map { clip in
            if thumbnails[clip.id] == nil, let thumb = Self.thumbnail(for: clip) {
                thumbnails[clip.id] = thumb
            }
            return Row(id: clip.id, preview: clip.preview, thumbnail: thumbnails[clip.id])
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
