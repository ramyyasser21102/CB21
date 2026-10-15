import Foundation
import CB21Core

/// Owns the History store and polls the system pasteboard.
@MainActor
final class CaptureService {
    static let shared = CaptureService()

    private(set) var store: ClipStore?
    private(set) var engine: CaptureEngine?
    private(set) var recoveredFrom: URL?
    private var task: Task<Void, Never>?

    /// `CB21_DATA_DIR` overrides the data folder, which lets tests use a throwaway one.
    static var dataDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["CB21_DATA_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cb21", isDirectory: true)
    }

    func start() {
        guard task == nil else { return }
        let dir = Self.dataDirectory
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let opened = try ClipStore.openRecovering(
                at: dir.appendingPathComponent("history.sqlite"),
                imagesDirectory: dir.appendingPathComponent("images", isDirectory: true)
            )
            store = opened.store
            recoveredFrom = opened.recoveredFrom
            let engine = CaptureEngine(pasteboard: SystemPasteboard(), store: opened.store)
            self.engine = engine
            task = Task {
                _ = try? await opened.store.sweepOrphanedImageFiles()
                while !Task.isCancelled {
                    _ = try? await engine.poll()
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
        } catch {
            NSLog("cb21: cannot open History: \(error)")
        }
    }
}
