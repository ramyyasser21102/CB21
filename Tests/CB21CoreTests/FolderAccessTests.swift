import Foundation
import Testing
@testable import CB21Core

private let home = URL(fileURLWithPath: "/Users/me", isDirectory: true)

@Test func protectedFoldersAreTheThreeUnderTheHomeFolder() {
    #expect(ProtectedFolder.allCases == [.desktop, .documents, .downloads])
    #expect(ProtectedFolder.desktop.url(home: home).path == "/Users/me/Desktop")
    #expect(ProtectedFolder.documents.url(home: home).path == "/Users/me/Documents")
    #expect(ProtectedFolder.downloads.url(home: home).path == "/Users/me/Downloads")
}

@Test func folderNamesAreReadable() {
    #expect(ProtectedFolder.documents.displayName == "Documents")
    #expect(ProtectedFolder.allCases.map(\.displayName) == ["Desktop", "Documents", "Downloads"])
}

// MARK: Which folder a path is in (decided from the path alone, never by touching the disk)

@Test func aFileInsideAProtectedFolderNeedsThatFolder() {
    #expect(FileAccessGuard.requiredFolders(forFileURLText: "file:///Users/me/Documents/Reports/Q3.pdf", home: home) == [.documents])
    #expect(FileAccessGuard.requiredFolders(forFileURLText: "file:///Users/me/Desktop/a.png", home: home) == [.desktop])
    #expect(FileAccessGuard.requiredFolders(forFileURLText: "file:///Users/me/Downloads/b.zip", home: home) == [.downloads])
}

@Test func percentEncodedAndPlainPathsAreUnderstood() {
    #expect(FileAccessGuard.requiredFolders(forFileURLText: "file:///Users/me/Documents/My%20Report.pdf", home: home) == [.documents])
    #expect(FileAccessGuard.requiredFolders(forFileURLText: "/Users/me/Downloads/plain path.txt", home: home) == [.downloads])
    #expect(FileAccessGuard.requiredFolders(forFileURLText: "  file:///Users/me/Desktop/a.png\n", home: home) == [.desktop])
}

@Test func theProtectedFolderItselfCounts() {
    #expect(FileAccessGuard.requiredFolders(for: URL(fileURLWithPath: "/Users/me/Documents"), home: home) == [.documents])
}

@Test func aSimilarlyNamedFolderIsNotProtected() {
    #expect(FileAccessGuard.requiredFolders(for: URL(fileURLWithPath: "/Users/me/Documents-old/a.txt"), home: home).isEmpty)
    #expect(FileAccessGuard.requiredFolders(for: URL(fileURLWithPath: "/Users/me/Desktop2/a.txt"), home: home).isEmpty)
}

@Test func filesElsewhereNeedNoPermission() {
    #expect(FileAccessGuard.requiredFolders(for: URL(fileURLWithPath: "/Users/me/Projects/app/main.swift"), home: home).isEmpty)
    #expect(FileAccessGuard.requiredFolders(for: URL(fileURLWithPath: "/Applications/Safari.app"), home: home).isEmpty)
    #expect(FileAccessGuard.requiredFolders(for: URL(fileURLWithPath: "/tmp/x.txt"), home: home).isEmpty)
}

@Test func dotDotCannotSneakAroundTheCheck() {
    let url = URL(fileURLWithPath: "/Users/me/Projects/../Documents/secret.txt")
    #expect(FileAccessGuard.requiredFolders(for: url, home: home) == [.documents])
}

@Test func aFileReferenceCouldBeAnywhereSoItNeedsAllThree() {
    // Decided from the text alone: making a URL out of a reference would look the file up on disk.
    #expect(FileAccessGuard.requiredFolders(forFileURLText: "file:///.file/id=6571367.12345", home: home) == [.desktop, .documents, .downloads])
}

@Test func theGuardOnlyLetsAFileBeReadOnceItsFoldersAreAllowed() {
    let text = "file:///Users/me/Documents/a.txt"
    #expect(!FileAccessGuard.mayRead(fileURLText: text, home: home, state: { _ in nil }))
    #expect(!FileAccessGuard.mayRead(fileURLText: text, home: home, state: { _ in .denied }))
    #expect(FileAccessGuard.mayRead(fileURLText: text, home: home, state: { $0 == .documents ? .allowed : nil }))
    // A folder that doesn't exist can't prompt, so it never blocks.
    #expect(FileAccessGuard.mayRead(fileURLText: text, home: home, state: { _ in .missing }))
    // Other folders don't matter for a file elsewhere.
    #expect(FileAccessGuard.mayRead(fileURLText: "file:///tmp/x", home: home, state: { _ in nil }))
}

@Test func aFileReferenceNeedsEveryFolderAllowed() {
    let reference = "file:///.file/id=1.2"
    #expect(!FileAccessGuard.mayRead(fileURLText: reference, home: home, state: { $0 == .desktop ? .allowed : nil }))
    #expect(FileAccessGuard.mayRead(fileURLText: reference, home: home, state: { _ in .allowed }))
}

@Test func aFileClipExposesItsAddressTextWithoutTouchingTheDisk() {
    let clip = Clip(representations: [Representation(kind: .file, typeIdentifier: "public.file-url",
                                                      data: Data("file:///Users/me/Documents/a.txt\n".utf8))])
    #expect(clip.fileURLText == "file:///Users/me/Documents/a.txt")
    let text = Clip(representations: [Representation(kind: .plainText, typeIdentifier: "public.utf8-plain-text", data: Data("hi".utf8))])
    #expect(text.fileURLText == nil)
}

// MARK: Reading the result of a listing attempt

private func posix(_ code: Int32) -> Error { NSError(domain: NSPOSIXErrorDomain, code: Int(code)) }
private func cocoa(_ code: Int) -> Error { NSError(domain: NSCocoaErrorDomain, code: code) }

@Test func aListingThatWorksMeansAllowed() {
    #expect(FolderAccess.check(.documents, home: home, listing: { _ in }) == .allowed)
}

@Test(arguments: [1, 13])
func permissionErrorsMeanDenied(code: Int32) {
    #expect(FolderAccess.check(.desktop, home: home, listing: { _ in throw posix(code) }) == .denied)
}

@Test func cocoaReadPermissionErrorMeansDenied() {
    #expect(FolderAccess.check(.downloads, home: home, listing: { _ in throw cocoa(NSFileReadNoPermissionError) }) == .denied)
}

@Test func aFolderThatDoesNotExistIsMissingNotDenied() {
    #expect(FolderAccess.check(.documents, home: home, listing: { _ in throw posix(2) }) == .missing)
    #expect(FolderAccess.check(.documents, home: home, listing: { _ in throw cocoa(NSFileReadNoSuchFileError) }) == .missing)
}

@Test func anyOtherFailureIsTreatedAsDeniedToStayOnTheSafeSide() {
    #expect(FolderAccess.check(.documents, home: home, listing: { _ in throw posix(5) }) == .denied)
}

@Test func theListingIsAskedAboutTheRightFolder() {
    var asked: [String] = []
    _ = FolderAccess.check(.downloads, home: home, listing: { asked.append($0.path) })
    #expect(asked == ["/Users/me/Downloads"])
}

// MARK: Remembering that the user pressed Allow

@Test func folderAccessIsNotRequestedByDefaultAndPersists() {
    #expect(SettingsValues().folderAccessRequested == false)
    let name = "cb21-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    var values = SettingsValues()
    values.folderAccessRequested = true
    SettingsPersistence(defaults: defaults).save(values)
    #expect(SettingsPersistence(defaults: defaults).load().folderAccessRequested)
}
