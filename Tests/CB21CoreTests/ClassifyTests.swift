import Testing
@testable import CB21Core

@Test(arguments: [
    ("public.png", Representation.Kind.image),
    ("com.adobe.pdf", .pdf),
    ("public.tiff", .image),
    ("public.jpeg", .image),
    ("public.file-url", .file),
    ("public.url", .link),
    ("public.rtf", .richText),
    ("public.html", .richText),
    ("public.utf8-plain-text", .plainText),
    ("public.utf16-plain-text", .plainText),
    ("NSStringPboardType", .plainText),
])
func knownTypeIdentifiersMapToAKind(typeIdentifier: String, expected: Representation.Kind) {
    #expect(Representation.Kind.classify(typeIdentifier) == expected)
}

@Test(arguments: ["dyn.ah62d4rv4gu8y6y4grf0gn5xbrzw1gydcr7u1e3cytf2gn", "com.apple.icns", "org.nspasteboard.source", ""])
func unknownTypeIdentifiersAreDropped(typeIdentifier: String) {
    #expect(Representation.Kind.classify(typeIdentifier) == nil)
}
