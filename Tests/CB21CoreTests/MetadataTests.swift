import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CB21Core

// MARK: Fixtures

private func pngData(width: Int, height: Int) -> Data {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}

private func pdfData(pages: Int, title: String? = nil) -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 100, height: 100)
    let info: CFDictionary? = title.map { [kCGPDFContextTitle: $0] as CFDictionary }
    let ctx = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, info)!
    for _ in 0..<pages {
        ctx.beginPDFPage(nil)
        ctx.fill(CGRect(x: 10, y: 10, width: 20, height: 20))
        ctx.endPDFPage()
    }
    ctx.closePDF()
    return data as Data
}

private func clip(_ kind: Representation.Kind, _ type: String, _ data: Data, source: String? = nil) -> Clip {
    Clip(representations: [Representation(kind: kind, typeIdentifier: type, data: data)],
         createdAt: Date(timeIntervalSince1970: 100), lastUsedAt: Date(timeIntervalSince1970: 200), sourceAppName: source)
}

private func plain(_ s: String, source: String? = nil) -> Clip {
    clip(.plainText, "public.utf8-plain-text", Data(s.utf8), source: source)
}

private func tempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

// MARK: Common facts

@Test func everyClipReportsTimesSizeAndSourceApp() {
    let meta = plain("hello", source: "Notes").metadata()
    #expect(meta.createdAt == Date(timeIntervalSince1970: 100))
    #expect(meta.lastUsedAt == Date(timeIntervalSince1970: 200))
    #expect(meta.byteCount == 5)
    #expect(meta.sourceAppName == "Notes")
}

// MARK: Text

@Test func textCountsCharactersWordsAndLines() {
    let meta = plain("one two\nthree  four\nfive").metadata()
    #expect(meta.detail == .text(TextFacts(characters: 24, words: 5, lines: 3)))
}

@Test func textCountsEmojiAsSingleCharactersAndIgnoresATrailingNewline() {
    #expect(plain("hi 👍🏽\n").metadata().detail == .text(TextFacts(characters: 4, words: 2, lines: 1)))
}

@Test func richTextWithoutPlainTextHasNoCounts() {
    let meta = clip(.richText, "public.rtf", Data("{\\rtf1 hi}".utf8)).metadata()
    #expect(meta.detail == .text(nil))
}

@Test func fullTextIsAvailableForTheDetailPane() {
    #expect(plain("a\nb").fullText == "a\nb")
}

// MARK: Images

@Test func imageReportsPixelSizeAndFormat() {
    let data = pngData(width: 30, height: 20)
    let meta = clip(.image, "public.png", data).metadata()
    #expect(meta.detail == .image(ImageFacts(pixelWidth: 30, pixelHeight: 20, format: "PNG")))
    #expect(meta.byteCount == data.count)
}

@Test func unreadableImageHasNoFacts() {
    #expect(clip(.image, "public.png", Data([1, 2, 3])).metadata().detail == .image(nil))
}

// MARK: PDFs

@Test func pdfDataReportsPagesAndTitle() {
    let meta = clip(.pdf, "com.adobe.pdf", pdfData(pages: 3, title: "Quarterly report")).metadata()
    #expect(meta.detail == .pdf(PDFFacts(pageCount: 3, title: "Quarterly report")))
}

@Test func pdfWithoutATitleHasNoneAndUnreadablePdfHasNoFacts() {
    #expect(clip(.pdf, "com.adobe.pdf", pdfData(pages: 1)).metadata().detail == .pdf(PDFFacts(pageCount: 1, title: nil)))
    #expect(clip(.pdf, "com.adobe.pdf", Data([0, 1])).metadata().detail == .pdf(nil))
}

// MARK: Files

@Test func existingFileReportsNameFolderKindSizeAndDate() throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("My Notes.txt")
    try Data("12345".utf8).write(to: file)
    let meta = clip(.file, "public.file-url", Data(file.absoluteString.utf8)).metadata()
    guard case .file(let facts) = meta.detail else { Issue.record("not a file"); return }
    #expect(facts.name == "My Notes.txt")
    #expect(facts.folder == dir.path || facts.folder == dir.resolvingSymlinksInPath().path)
    #expect(facts.exists)
    #expect(facts.fileSize == 5)
    #expect(facts.modified != nil)
    #expect(facts.kind?.isEmpty == false)
    #expect(facts.pdf == nil)
}

@Test func missingFileIsReportedAsGoneButKeepsItsName() {
    let url = URL(fileURLWithPath: "/tmp/cb21-no-such-\(UUID().uuidString)/Gone.pdf")
    let meta = clip(.file, "public.file-url", Data(url.absoluteString.utf8)).metadata()
    guard case .file(let facts) = meta.detail else { Issue.record("not a file"); return }
    #expect(facts.name == "Gone.pdf")
    #expect(!facts.exists)
    #expect(facts.fileSize == nil)
    #expect(facts.pdf == nil)
}

@Test func pdfFileReportsPagesAndTitleFromDisk() throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("Doc.pdf")
    try pdfData(pages: 2, title: "On disk").write(to: file)
    let meta = clip(.file, "public.file-url", Data(file.absoluteString.utf8)).metadata()
    guard case .file(let facts) = meta.detail else { Issue.record("not a file"); return }
    #expect(facts.pdf == PDFFacts(pageCount: 2, title: "On disk"))
}

// MARK: Links

@Test func linkReportsHostAndFullURL() {
    let meta = clip(.link, "public.url", Data("https://www.example.com/a/b?q=1".utf8)).metadata()
    #expect(meta.detail == .link(LinkFacts(url: "https://www.example.com/a/b?q=1", host: "www.example.com")))
}

@Test func linkWithoutAHostStillShowsItsText() {
    let meta = clip(.link, "public.url", Data("mailto:me@example.com".utf8)).metadata()
    #expect(meta.detail == .link(LinkFacts(url: "mailto:me@example.com", host: nil)))
}

// MARK: Display text (Detail pane)

@Test func shortTextIsShownInFull() {
    let shown = plain("short text").displayText()
    #expect(shown == DisplayText(text: "short text", isTruncated: false))
}

@Test func textLongerThanTheLimitIsCutAndFlagged() {
    let long = String(repeating: "ab", count: 6_000) // 12,000 characters
    let shown = try! #require(plain(long).displayText())
    #expect(shown.text.count == 10_000)
    #expect(shown.isTruncated)
}

@Test func textExactlyAtTheLimitIsNotFlagged() {
    let exact = String(repeating: "x", count: 10_000)
    #expect(plain(exact).displayText()?.isTruncated == false)
}

@Test func clipWithoutPlainTextHasNoDisplayText() {
    #expect(clip(.link, "public.url", Data("https://a.b".utf8)).displayText() == nil)
}
