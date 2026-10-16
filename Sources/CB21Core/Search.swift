import Foundation

/// The text Search matches against, built from a Clip and stored with it.
public enum SearchText {
    /// How much of a Clip's text is kept for Search.
    public static let contentLimit = 2_000
    static let linkLimit = 500

    /// Lowercase with accents removed, so "Café" and "cafe" match.
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Text, link, file name and source app. Images and PDFs add nothing of their own.
    public static func build(representations: [Representation], sourceAppName: String?) -> String {
        var parts: [String] = []
        if let text = representations.first(where: { $0.kind == .plainText }) {
            parts.append(String(String(decoding: text.data, as: UTF8.self).prefix(contentLimit)))
        }
        if let link = representations.first(where: { $0.kind == .link }) {
            parts.append(String(String(decoding: link.data, as: UTF8.self).prefix(linkLimit)))
        }
        if let file = representations.first(where: { $0.kind == .file }) {
            let raw = String(decoding: file.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let url = URL(string: raw) ?? URL(fileURLWithPath: raw)
            parts.append(url.lastPathComponent)
        }
        if let sourceAppName { parts.append(sourceAppName) }
        return normalize(parts.joined(separator: "\n"))
    }
}

public enum ClipSearch {
    /// True when every word typed appears in `searchText`, in any order. A blank query matches everything.
    public static func matches(_ query: String, in searchText: String) -> Bool {
        let words = SearchText.normalize(query).split(whereSeparator: \.isWhitespace)
        return words.allSatisfy { searchText.contains($0) }
    }

    public static func filter<T>(_ items: [T], query: String, text: (T) -> String) -> [T] {
        items.filter { matches(query, in: text($0)) }
    }
}

extension Clip {
    public var searchText: String {
        SearchText.build(representations: representations, sourceAppName: sourceAppName)
    }
}
