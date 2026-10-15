import Foundation
import Testing
@testable import CB21Core

private func text(_ s: String) -> Representation {
    Representation(kind: .plainText, typeIdentifier: "public.utf8-plain-text", data: Data(s.utf8))
}

@Test func clipsWithSameContentHaveSameKeyRegardlessOfIdAndDates() {
    let a = Clip(representations: [text("hello")], createdAt: Date(timeIntervalSince1970: 1))
    let b = Clip(representations: [text("hello")], createdAt: Date(timeIntervalSince1970: 99))
    #expect(a.id != b.id)
    #expect(a.contentKey == b.contentKey)
}

@Test func clipsWithDifferentContentHaveDifferentKeys() {
    let a = Clip(representations: [text("hello")])
    let b = Clip(representations: [text("world")])
    #expect(a.contentKey != b.contentKey)
}

@Test func contentKeyUsesThePreferredRepresentation() {
    let rich = Representation(kind: .richText, typeIdentifier: "public.rtf", data: Data("{rtf}".utf8))
    let a = Clip(representations: [text("hi"), rich])
    let b = Clip(representations: [rich, text("different plain")])
    #expect(a.preferred.kind == .richText)
    #expect(a.contentKey == b.contentKey)
}

@Test func imageIsPreferredOverText() {
    let image = Representation(kind: .image, typeIdentifier: "public.png", data: Data([1, 2, 3]))
    let clip = Clip(representations: [text("caption"), image])
    #expect(clip.preferred.kind == .image)
}

@Test func totalByteCountSumsAllRepresentations() {
    let clip = Clip(representations: [text("abc"), text("de")])
    #expect(clip.byteCount == 5)
}

@Test func lastUsedStartsAtCreation() {
    let date = Date(timeIntervalSince1970: 42)
    let clip = Clip(representations: [text("x")], createdAt: date)
    #expect(clip.lastUsedAt == date)
}
