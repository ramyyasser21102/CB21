import Foundation
import Testing
@testable import CB21Core

private func rep(_ kind: Representation.Kind, _ type: String, _ s: String) -> Representation {
    Representation(kind: kind, typeIdentifier: type, data: Data(s.utf8))
}

@Test func shortTextShowsAsIs() {
    let clip = Clip(representations: [rep(.plainText, "public.utf8-plain-text", "hello world")])
    #expect(clip.preview == .text("hello world"))
}

@Test func textShowsOnlyItsFirstNonEmptyLineTrimmed() {
    let clip = Clip(representations: [rep(.plainText, "public.utf8-plain-text", "\n  \n   first line  \nsecond")])
    #expect(clip.preview == .text("first line"))
}

@Test func longTextIsTruncatedTo60CharactersWithAnEllipsis() {
    let long = String(repeating: "a", count: 100)
    let clip = Clip(representations: [rep(.plainText, "public.utf8-plain-text", long)])
    #expect(clip.preview == .text(String(repeating: "a", count: 59) + "…"))
}

@Test func textOfExactly60CharactersIsNotTruncated() {
    let exact = String(repeating: "b", count: 60)
    let clip = Clip(representations: [rep(.plainText, "public.utf8-plain-text", exact)])
    #expect(clip.preview == .text(exact))
}

@Test func blankTextGetsAPlaceholder() {
    let clip = Clip(representations: [rep(.plainText, "public.utf8-plain-text", "  \n ")])
    #expect(clip.preview == .text("(blank)"))
}

@Test func richTextShowsItsPlainTextRepresentation() {
    let clip = Clip(representations: [rep(.richText, "public.rtf", "{\\rtf1 hi}"), rep(.plainText, "public.utf8-plain-text", "hi")])
    #expect(clip.preview == .text("hi"))
}

@Test func richTextWithoutPlainTextGetsAPlaceholder() {
    let clip = Clip(representations: [rep(.richText, "public.rtf", "{\\rtf1 hi}")])
    #expect(clip.preview == .text("Rich text"))
}

@Test func linkShowsItsURL() {
    let clip = Clip(representations: [rep(.plainText, "public.utf8-plain-text", "see this"), rep(.link, "public.url", "https://example.com/a")])
    #expect(clip.preview == .link("https://example.com/a"))
}

@Test func fileShowsItsNameDecoded() {
    let clip = Clip(representations: [rep(.file, "public.file-url", "file:///Users/me/My%20Report.pdf")])
    #expect(clip.preview == .file("My Report.pdf"))
}

@Test func imageIsAnImagePreview() {
    let clip = Clip(representations: [Representation(kind: .image, typeIdentifier: "public.png", data: Data([1, 2]))])
    #expect(clip.preview == .image)
}


@Test func pdfDataIsAPdfPreview() {
    let clip = Clip(representations: [rep(.plainText, "public.utf8-plain-text", "page text"), Representation(kind: .pdf, typeIdentifier: "com.adobe.pdf", data: Data([1]))])
    #expect(clip.preview == .pdf)
}

@Test func pdfRanksAfterImagesAndBeforeFilesAndText() {
    let image = Representation(kind: .image, typeIdentifier: "public.png", data: Data([1]))
    let pdf = Representation(kind: .pdf, typeIdentifier: "com.adobe.pdf", data: Data([2]))
    let file = rep(.file, "public.file-url", "file:///a.txt")
    #expect(Clip(representations: [pdf, image]).preferred.kind == .image)
    #expect(Clip(representations: [file, pdf]).preferred.kind == .pdf)
}
