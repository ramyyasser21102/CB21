import AppKit

/// One clip in the menu, drawn by us instead of by the menu. This menu doesn't draw item images on recent macOS
/// versions, and a plain item can't hold a button, so the row draws its own icon or thumbnail and its own star.
///
/// Clicking the star pins or unpins; clicking anywhere else on the row picks it (⌥-click still pins or unpins).
final class ClipMenuRowView: NSView {
    struct Content {
        let title: String
        /// An SF Symbol for links, files and PDFs; nil for plain text.
        let symbol: String?
        let thumbnail: NSImage?
        /// The digit for ⌘1 to ⌘9, or nil past the ninth row.
        let number: String?
        let isMostRecent: Bool
        let isPinned: Bool
    }

    static let size = NSSize(width: 340, height: 26)

    private let title: String
    private let symbol: String?
    private let thumbnail: NSImage?
    private let number: String?
    private let isMostRecent: Bool
    private(set) var isPinned: Bool

    /// Set by the menu as the highlight moves (mouse or arrow keys); a custom view must draw it itself.
    var isHighlighted = false {
        didSet { if isHighlighted != oldValue { needsDisplay = true } }
    }
    private var starHovered = false {
        didSet { if starHovered != oldValue { needsDisplay = true } }
    }

    /// The row was chosen. The flag says whether ⌥ was held.
    var onPick: ((_ optionHeld: Bool) -> Void)?
    /// The star was clicked. The flag is the new pinned state.
    var onTogglePin: ((_ pinned: Bool) -> Void)?

    init(_ content: Content) {
        title = content.title
        symbol = content.symbol
        thumbnail = content.thumbnail
        number = content.number
        isMostRecent = content.isMostRecent
        isPinned = content.isPinned
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        updateAccessibility()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private var starRect: NSRect {
        NSRect(x: bounds.width - 36, y: 0, width: 32, height: bounds.height)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 1), xRadius: 5, yRadius: 5).fill()
        }
        let primary: NSColor = isHighlighted ? .selectedMenuItemTextColor : .labelColor
        let secondary: NSColor = isHighlighted ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.75) : .secondaryLabelColor

        // The most recent clip keeps its dot.
        if isMostRecent {
            primary.setFill()
            NSBezierPath(ovalIn: NSRect(x: 15, y: bounds.midY - 3.5, width: 7, height: 7)).fill()
        }

        // Icon or thumbnail.
        let iconRect = NSRect(x: 30, y: (bounds.height - 16) / 2, width: 16, height: 16)
        if let thumbnail {
            thumbnail.draw(in: iconRect)
        } else if let symbol, let image = Self.tinted(symbol, points: 13, color: secondary) {
            let fitted = NSRect(x: iconRect.minX, y: bounds.midY - image.size.height / 2,
                                width: min(image.size.width, 16), height: image.size.height)
            image.draw(in: fitted)
        }

        let hasIcon = thumbnail != nil || symbol != nil
        let textX: CGFloat = hasIcon ? 54 : 30

        // ⌘ number.
        var numberWidth: CGFloat = 0
        if let number {
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: secondary]
            let text = NSAttributedString(string: "⌘\(number)", attributes: attributes)
            numberWidth = ceil(text.size().width)
            text.draw(at: NSPoint(x: starRect.minX - numberWidth - 6, y: bounds.midY - text.size().height / 2))
        }

        // Title.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 0), .foregroundColor: primary, .paragraphStyle: paragraph,
        ]
        let titleRect = NSRect(x: textX, y: bounds.midY - 9, width: starRect.minX - numberWidth - 14 - textX, height: 18)
        (title as NSString).draw(with: titleRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: titleAttributes)

        // Star: filled yellow when pinned. An unpinned row shows a faint outline all the time, so the ability to pin is
        // always visible, and brighter while the row is highlighted or the pointer is over the star.
        let name = isPinned ? "star.fill" : "star"
        let color: NSColor
        if isPinned {
            color = .systemYellow
        } else if starHovered {
            color = primary
        } else if isHighlighted {
            color = secondary
        } else {
            color = secondary.withAlphaComponent(0.4)
        }
        if let star = Self.tinted(name, points: 14, color: color) {
            star.draw(at: NSPoint(x: starRect.midX - star.size.width / 2, y: bounds.midY - star.size.height / 2),
                      from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    private static func tinted(_ name: String, points: CGFloat, color: NSColor) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: points, weight: .regular)) else { return nil }
        let result = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        return result
    }

    // MARK: Mouse

    override func mouseMoved(with event: NSEvent) {
        starHovered = starRect.contains(convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        starHovered = false
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if starRect.contains(point) {
            togglePin()
        } else {
            onPick?(event.modifierFlags.contains(.option))
        }
    }

    // MARK: Pinning

    /// Flips the star at once, so the click is seen straight away. The menu can't reorder itself while it is open;
    /// the pinned section is rebuilt the next time it opens.
    func togglePin() {
        isPinned.toggle()
        updateAccessibility()
        needsDisplay = true
        onTogglePin?(isPinned)
    }

    /// Mirrors the state without calling back, for the ⌥-click path that already handled it.
    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        updateAccessibility()
        needsDisplay = true
    }

    private func updateAccessibility() {
        let spoken = [isPinned ? "Pinned" : nil, isMostRecent ? "Most recent" : nil].compactMap { $0 }
        setAccessibilityLabel((spoken + [title]).joined(separator: ". "))
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: isPinned ? "Unpin" : "Pin") { [weak self] in
                self?.togglePin()
                return true
            },
        ])
    }
}
