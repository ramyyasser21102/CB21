import Foundation
import SQLite3
import Testing
@testable import CB21Core

private func rep(_ kind: Representation.Kind, _ type: String, _ s: String) -> Representation {
    Representation(kind: kind, typeIdentifier: type, data: Data(s.utf8))
}

private func clip(_ reps: [Representation], source: String? = nil) -> Clip {
    Clip(representations: reps, sourceAppName: source)
}

private func plain(_ s: String, source: String? = nil) -> Clip {
    clip([rep(.plainText, "public.utf8-plain-text", s)], source: source)
}

// MARK: Normalizing

@Test func normalizingIgnoresCaseAndAccents() {
    #expect(SearchText.normalize("Un CAFÉ Noir") == "un cafe noir")
    #expect(SearchText.normalize("ÀÉÎÕÜ") == "aeiou")
}

// MARK: Matching

@Test func everyTypedWordMustMatchInAnyOrder() {
    let text = SearchText.normalize("Un café noir, s'il vous plaît")
    #expect(ClipSearch.matches("noir cafe", in: text))
    #expect(ClipSearch.matches("CAFÉ", in: text))
    #expect(!ClipSearch.matches("cafe lune", in: text))
}

@Test func emptyOrBlankQueryMatchesEverything() {
    #expect(ClipSearch.matches("", in: "anything"))
    #expect(ClipSearch.matches("   ", in: ""))
}

@Test func matchingIsSubstringBased() {
    #expect(ClipSearch.matches("lipbo", in: SearchText.normalize("clipboard")))
}

@Test func filterKeepsTheOriginalOrderAndDropsNonMatches() {
    let items = ["Red apple", "green pear", "Apple pie", "banana"]
    let found = ClipSearch.filter(items, query: "APPLE") { SearchText.normalize($0) }
    #expect(found == ["Red apple", "Apple pie"])
    #expect(ClipSearch.filter(items, query: "") { SearchText.normalize($0) } == items)
}

// MARK: What a Clip contributes

@Test func textClipSearchTextHoldsItsTextAndSourceApp() {
    let text = plain("Hello Wörld", source: "Notes").searchText
    #expect(text.contains("hello world"))
    #expect(text.contains("notes"))
}

@Test func searchTextIsCappedAt2000CharactersOfContent() {
    let long = String(repeating: "a", count: 5_000) + "needle"
    let text = plain(long).searchText
    #expect(text.count <= SearchText.contentLimit + 200)
    #expect(!text.contains("needle"))
}

@Test func linkClipIsFoundByItsURL() {
    let c = clip([rep(.link, "public.url", "https://example.com/Docs/Intro")])
    #expect(ClipSearch.matches("example.com/docs", in: c.searchText))
}

@Test func fileClipIsFoundByItsFileName() {
    let c = clip([rep(.file, "public.file-url", "file:///Users/me/Quarterly%20Report.pdf")])
    #expect(ClipSearch.matches("quarterly report", in: c.searchText))
    #expect(ClipSearch.matches("pdf", in: c.searchText))
}

@Test func imageAndPdfClipsAreFoundBySourceAppOnly() {
    let image = clip([Representation(kind: .image, typeIdentifier: "public.png", data: Data([1, 2, 3]))], source: "Preview")
    let pdf = clip([Representation(kind: .pdf, typeIdentifier: "com.adobe.pdf", data: Data([1, 2, 3]))], source: "Acrobat")
    #expect(ClipSearch.matches("preview", in: image.searchText))
    #expect(ClipSearch.matches("acrobat", in: pdf.searchText))
    #expect(!ClipSearch.matches("png", in: image.searchText))
}

@Test func richTextWithoutPlainTextIsFoundBySourceAppOnly() {
    let c = clip([rep(.richText, "public.rtf", "{\\rtf1 secret}")], source: "Pages")
    #expect(ClipSearch.matches("pages", in: c.searchText))
    #expect(!ClipSearch.matches("secret", in: c.searchText))
}

// MARK: Stored with each Clip

@Test func insertedClipsAreInTheSearchIndex() async throws {
    let store = try ClipStore.inMemory()
    let a = plain("Pineapple pizza", source: "Safari")
    let b = plain("Tax return 2025")
    try await store.insert(a)
    try await store.insert(b)
    let index = try await store.searchIndex()
    #expect(Set(index.keys) == [a.id, b.id])
    #expect(ClipSearch.matches("pizza safari", in: index[a.id] ?? ""))
    #expect(ClipSearch.matches("tax", in: index[b.id] ?? ""))
    #expect(!ClipSearch.matches("tax", in: index[a.id] ?? ""))
}

@Test func deletedClipsLeaveTheIndex() async throws {
    let store = try ClipStore.inMemory()
    let a = plain("gone soon")
    try await store.insert(a)
    try await store.delete(ids: [a.id])
    #expect(try await store.searchIndex().isEmpty)
}

// MARK: Migration 4 fills in existing clips

private func makeVersion3Database(at path: String, textID: UUID, imageID: UUID) throws {
    var db: OpaquePointer?
    #expect(sqlite3_open(path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    let sql = """
        CREATE TABLE clips (
            id TEXT PRIMARY KEY, content_key TEXT NOT NULL, created_at REAL NOT NULL,
            last_used_at REAL NOT NULL, byte_count INTEGER NOT NULL,
            source_app_name TEXT, pinned_at REAL, search_text TEXT);
        CREATE TABLE representations (
            clip_id TEXT NOT NULL REFERENCES clips(id) ON DELETE CASCADE, position INTEGER NOT NULL,
            kind TEXT NOT NULL, type_identifier TEXT NOT NULL, data BLOB NOT NULL, file_name TEXT,
            PRIMARY KEY (clip_id, position));
        INSERT INTO clips (id, content_key, created_at, last_used_at, byte_count, source_app_name)
            VALUES ('\(textID.uuidString)', 'k1', 10, 20, 11, 'Notes');
        INSERT INTO representations VALUES ('\(textID.uuidString)', 0, 'plainText', 'public.utf8-plain-text', X'48454C4C4F20574F524C44', NULL);
        INSERT INTO clips (id, content_key, created_at, last_used_at, byte_count, source_app_name)
            VALUES ('\(imageID.uuidString)', 'k2', 11, 21, 3, 'Preview');
        INSERT INTO representations VALUES ('\(imageID.uuidString)', 0, 'image', 'public.png', X'000000', 'img-file');
        PRAGMA user_version = 3;
        """
    #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
}

@Test func existingClipsGetTheirSearchTextWhenTheDatabaseIsUpgraded() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let path = dir.appendingPathComponent("history.sqlite").path
    let textID = UUID(), imageID = UUID()
    try makeVersion3Database(at: path, textID: textID, imageID: imageID)
    let store = try ClipStore(path: path)
    #expect(try await store.schemaVersion() == ClipStore.latestSchemaVersion)
    let index = try await store.searchIndex()
    #expect(ClipSearch.matches("hello world notes", in: index[textID] ?? ""))
    #expect(ClipSearch.matches("preview", in: index[imageID] ?? ""))
}
