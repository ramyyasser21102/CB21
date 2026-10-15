import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

public struct TextFacts: Sendable, Equatable {
    public let characters: Int
    public let words: Int
    public let lines: Int

    public init(characters: Int, words: Int, lines: Int) {
        self.characters = characters
        self.words = words
        self.lines = lines
    }
}

public struct ImageFacts: Sendable, Equatable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    /// For example "PNG" or "JPEG".
    public let format: String

    public init(pixelWidth: Int, pixelHeight: Int, format: String) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.format = format
    }
}

public struct PDFFacts: Sendable, Equatable {
    public let pageCount: Int
    public let title: String?

    public init(pageCount: Int, title: String?) {
        self.pageCount = pageCount
        self.title = title
    }
}

public struct FileFacts: Sendable, Equatable {
    public let name: String
    public let folder: String
    public let exists: Bool
    /// For example "PDF document". Nil when the file is gone.
    public let kind: String?
    public let fileSize: Int?
    public let modified: Date?
    /// Page count and title, for PDF files that still exist.
    public let pdf: PDFFacts?
}

public struct LinkFacts: Sendable, Equatable {
    public let url: String
    public let host: String?

    public init(url: String, host: String?) {
        self.url = url
        self.host = host
    }
}

/// Facts about a Clip for the Detail pane. Worked out on demand; nothing here is stored.
/// Each case holds nil when the content couldn't be read.
public struct ClipMetadata: Sendable, Equatable {
    public enum Detail: Sendable, Equatable {
        case text(TextFacts?)
        case image(ImageFacts?)
        case pdf(PDFFacts?)
        case file(FileFacts)
        case link(LinkFacts)
    }

    public let createdAt: Date
    public let lastUsedAt: Date
    public let byteCount: Int
    public let sourceAppName: String?
    public let detail: Detail
}

/// Text for the Detail pane, cut to a length the window can show comfortably.
public struct DisplayText: Sendable, Equatable {
    public static let defaultLimit = 10_000

    public let text: String
    public let isTruncated: Bool

    public init(text: String, isTruncated: Bool) {
        self.text = text
        self.isTruncated = isTruncated
    }
}

extension Clip {
    public func displayText(limit: Int = DisplayText.defaultLimit) -> DisplayText? {
        guard let full = fullText else { return nil }
        guard full.count > limit else { return DisplayText(text: full, isTruncated: false) }
        return DisplayText(text: String(full.prefix(limit)), isTruncated: true)
    }

    /// The Clip's plain text in full, when it has any.
    public var fullText: String? {
        representations.first { $0.kind == .plainText }.map { String(decoding: $0.data, as: UTF8.self) }
    }

    public func metadata() -> ClipMetadata {
        ClipMetadata(
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            byteCount: byteCount,
            sourceAppName: sourceAppName,
            detail: detailFacts()
        )
    }

    private func detailFacts() -> ClipMetadata.Detail {
        let main = preferred
        switch main.kind {
        case .image:
            return .image(Self.imageFacts(main.data))
        case .pdf:
            return .pdf(Self.pdfFacts(PDFDocument(data: main.data)))
        case .file:
            return .file(Self.fileFacts(String(decoding: main.data, as: UTF8.self)))
        case .link:
            let text = String(decoding: main.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return .link(LinkFacts(url: text, host: URL(string: text)?.host))
        case .richText, .plainText:
            return .text(fullText.map(Self.textFacts))
        }
    }

    private static func textFacts(_ text: String) -> TextFacts {
        let words = text.split(whereSeparator: \.isWhitespace).count
        var body = Substring(text)
        if body.last?.isNewline == true { body = body.dropLast() }
        let lines = text.isEmpty ? 0 : body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
        return TextFacts(characters: text.count - (text.last?.isNewline == true ? 1 : 0), words: words, lines: lines)
    }

    private static func imageFacts(_ data: Data) -> ImageFacts? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let format = CGImageSourceGetType(source)
            .flatMap { UTType($0 as String)?.preferredFilenameExtension?.uppercased() } ?? "Image"
        return ImageFacts(pixelWidth: width, pixelHeight: height, format: format == "JPG" ? "JPEG" : format)
    }

    private static func pdfFacts(_ document: PDFDocument?) -> PDFFacts? {
        guard let document, document.pageCount > 0 else { return nil }
        let title = (document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
        return PDFFacts(pageCount: document.pageCount, title: title)
    }

    private static func fileFacts(_ raw: String) -> FileFacts {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: text) ?? URL(fileURLWithPath: text)
        let name = url.lastPathComponent
        let folder = url.deletingLastPathComponent().path
        let exists = FileManager.default.fileExists(atPath: url.path)
        guard exists else {
            return FileFacts(name: name, folder: folder, exists: false, kind: nil, fileSize: nil, modified: nil, pdf: nil)
        }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .localizedTypeDescriptionKey])
        let pdf = url.pathExtension.lowercased() == "pdf" ? pdfFacts(PDFDocument(url: url)) : nil
        return FileFacts(
            name: name,
            folder: folder,
            exists: true,
            kind: values?.localizedTypeDescription,
            fileSize: values?.fileSize,
            modified: values?.contentModificationDate,
            pdf: pdf
        )
    }
}
