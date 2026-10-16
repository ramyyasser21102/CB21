import Foundation

/// The folders macOS guards: it asks the user before an app may read inside them.
public enum ProtectedFolder: CaseIterable, Sendable {
    case desktop, documents, downloads

    public var displayName: String {
        switch self {
        case .desktop: "Desktop"
        case .documents: "Documents"
        case .downloads: "Downloads"
        }
    }

    public func url(home: URL) -> URL {
        home.appendingPathComponent(displayName, isDirectory: true)
    }
}

public enum FolderAccessState: Sendable, Equatable {
    case allowed
    case denied
    /// The folder doesn't exist, so nothing can be asked or read.
    case missing
}

public enum FolderAccess {
    /// Tries to list the folder, which is what makes macOS ask the first time. The listing is passed in so it can be
    /// replaced in tests. Once the user has decided, calling this again never prompts.
    public static func check(
        _ folder: ProtectedFolder,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        listing: (URL) throws -> Void = { _ = try FileManager.default.contentsOfDirectory(atPath: $0.path) }
    ) -> FolderAccessState {
        do {
            try listing(folder.url(home: home))
            return .allowed
        } catch {
            let ns = error as NSError
            switch (ns.domain, ns.code) {
            case (NSPOSIXErrorDomain, Int(ENOENT)), (NSCocoaErrorDomain, NSFileReadNoSuchFileError), (NSCocoaErrorDomain, NSFileNoSuchFileError):
                return .missing
            default:
                // Permission errors, and anything unexpected: stay on the safe side and treat it as not allowed.
                return .denied
            }
        }
    }
}

/// Decides whether a file may be read now, from its text alone. Reading a file inside a protected folder before the
/// user has allowed it is what makes macOS show a surprise prompt, so the answer never touches the disk.
///
/// It works on the stored text, not on a `URL`: turning a file-reference URL (`file:///.file/id=...`) into a path makes
/// Foundation look the file up on disk, which is exactly what must not happen before access is allowed.
public enum FileAccessGuard {
    public static func requiredFolders(
        forFileURLText text: String,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [ProtectedFolder] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A file reference hides the real path, so it could be inside any of the folders.
        if trimmed.contains("/.file/id=") { return ProtectedFolder.allCases }
        let url = URL(string: trimmed) ?? URL(fileURLWithPath: trimmed)
        return requiredFolders(for: url, home: home)
    }

    /// For a URL that already holds a plain path.
    public static func requiredFolders(
        for url: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [ProtectedFolder] {
        let path = url.standardizedFileURL.path
        return ProtectedFolder.allCases.filter { folder in
            let root = folder.url(home: home).standardizedFileURL.path
            return path == root || path.hasPrefix(root + "/")
        }
    }

    /// `state` returns what is known about a folder, or nil if it hasn't been checked yet.
    public static func mayRead(
        fileURLText text: String,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        state: (ProtectedFolder) -> FolderAccessState?
    ) -> Bool {
        requiredFolders(forFileURLText: text, home: home).allSatisfy { state($0) == .allowed || state($0) == .missing }
    }
}
