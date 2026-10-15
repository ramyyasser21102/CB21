import Foundation

/// What the menu and History window show for a Clip.
public enum ClipPreview: Sendable, Equatable {
    case text(String)
    case link(String)
    case file(String)
    /// The app draws a thumbnail from the Clip's image Representation.
    case image
    /// PDF data copied from an app. The app draws the first page.
    case pdf

    public static let maxTextLength = 60
}

extension Clip {
    public var preview: ClipPreview {
        let main = preferred
        switch main.kind {
        case .image:
            return .image
        case .pdf:
            return .pdf
        case .file:
            let string = String(decoding: main.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = URL(string: string)?.lastPathComponent ?? ""
            return .file(name.isEmpty ? string : name)
        case .link:
            return .link(String(decoding: main.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        case .richText, .plainText:
            guard let plain = representations.first(where: { $0.kind == .plainText }) else {
                return .text("Rich text")
            }
            return .text(Self.firstLine(of: String(decoding: plain.data, as: UTF8.self)))
        }
    }

    private static func firstLine(of text: String) -> String {
        let line = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let line else { return "(blank)" }
        let limit = ClipPreview.maxTextLength
        return line.count > limit ? String(line.prefix(limit - 1)) + "…" : line
    }
}
