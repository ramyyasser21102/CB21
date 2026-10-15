import CryptoKit
import Foundation

/// One format of a Clip's content.
public struct Representation: Sendable, Equatable {
    public enum Kind: String, Sendable, CaseIterable {
        case image, file, link, richText, plainText

        /// Lower value wins when choosing the preferred Representation.
        fileprivate var priority: Int {
            Self.allCases.firstIndex(of: self) ?? Self.allCases.count
        }
    }

    public let kind: Kind
    public let typeIdentifier: String
    public let data: Data

    public init(kind: Kind, typeIdentifier: String, data: Data) {
        self.kind = kind
        self.typeIdentifier = typeIdentifier
        self.data = data
    }
}

/// One copy event, holding every Representation the source app offered.
public struct Clip: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let representations: [Representation]
    public let createdAt: Date
    public var lastUsedAt: Date

    public init(
        id: UUID = UUID(),
        representations: [Representation],
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        precondition(!representations.isEmpty, "A Clip needs at least one Representation")
        self.id = id
        self.representations = representations
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt ?? createdAt
    }

    /// The Representation that stands for the Clip when comparing and previewing.
    public var preferred: Representation {
        representations.min { $0.kind.priority < $1.kind.priority }!
    }

    /// Stable key for the Duplicate rule: equal content gives an equal key.
    public var contentKey: String {
        var hasher = SHA256()
        hasher.update(data: Data(preferred.kind.rawValue.utf8))
        hasher.update(data: preferred.data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Total stored bytes across all Representations.
    public var byteCount: Int {
        representations.reduce(0) { $0 + $1.data.count }
    }
}

extension Representation.Kind {
    /// Maps a pasteboard type identifier to a Kind. Types cb21 doesn't keep return nil.
    public static func classify(_ typeIdentifier: String) -> Representation.Kind? {
        switch typeIdentifier {
        case "public.png", "public.tiff", "public.jpeg", "public.heic", "com.compuserve.gif":
            .image
        case "public.file-url":
            .file
        case "public.url":
            .link
        case "public.rtf", "public.html", "com.apple.flat-rtfd", "com.apple.webarchive":
            .richText
        case "public.utf8-plain-text", "public.utf16-plain-text", "NSStringPboardType":
            .plainText
        default:
            nil
        }
    }
}
