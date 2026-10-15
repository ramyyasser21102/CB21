import AppKit
import Foundation
import CB21Core

/// Owns the History store and polls the system pasteboard.
@MainActor
final class CaptureService {
    static let shared = CaptureService()

    let model = HistoryModel()
    let settings = SettingsModel()
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

    /// Puts a Clip back on the pasteboard. It moves to the top and is not captured again.
    func recopy(id: UUID) {
        guard let engine, let store else { return }
        Task {
            try? await engine.recopy(id: id)
            await model.refresh(from: store)
        }
    }

    /// Applies new Limits. If that would delete Clips, asks first. Returns whether the change was applied.
    func applyLimits(_ limits: Limits) async -> Bool {
        guard let store else { return false }
        let evicted = (try? await store.evictionCount(for: limits)) ?? 0
        if evicted > 0 {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Delete \(evicted) older \(evicted == 1 ? "clip" : "clips")?"
            alert.informativeText = "These limits are lower than your current History. The least recently used clips will be permanently deleted now."
            alert.addButton(withTitle: "Lower Limits")
            alert.addButton(withTitle: "Cancel")
            alert.buttons.first?.hasDestructiveAction = true
            guard alert.runModal() == .alertFirstButtonReturn else { return false }
        }
        _ = try? await store.setLimits(limits)
        settings.update { $0.limits = limits }
        await model.refresh(from: store)
        return true
    }

    /// Permanently deletes Clips from History and disk.
    func delete(ids: Set<UUID>) {
        guard let store, !ids.isEmpty else { return }
        Task {
            try? await store.delete(ids: Array(ids))
            await model.refresh(from: store)
        }
    }

    /// Asks for confirmation, then permanently deletes the whole History.
    func confirmAndClearAll() {
        guard let store, !model.rows.isEmpty else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear all history?"
        alert.informativeText = "This permanently deletes \(model.rows.count) clips from this Mac. It can't be undone."
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            try? await store.deleteAll()
            await model.refresh(from: store)
        }
    }

    func start() {
        guard task == nil else { return }
        let dir = Self.dataDirectory
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let opened = try ClipStore.openRecovering(
                at: dir.appendingPathComponent("history.sqlite"),
                imagesDirectory: dir.appendingPathComponent("images", isDirectory: true),
                limits: settings.values.limits
            )
            store = opened.store
            recoveredFrom = opened.recoveredFrom
            let pasteboard = SystemPasteboard()
            let engine = CaptureEngine(pasteboard: pasteboard, store: opened.store)
            self.engine = engine
            let model = self.model
            if opened.recoveredFrom != nil { model.post(.databaseRecovered) }
            task = Task {
                _ = try? await opened.store.sweepOrphanedImageFiles()
                await model.refresh(from: opened.store)
                while !Task.isCancelled {
                    model.setPasteboardAccessDenied(pasteboard.isAccessDenied)
                    switch try? await engine.poll() {
                    case .captured(.rejectedTooLarge):
                        model.post(.clipTooLarge)
                    case .captured:
                        await model.refresh(from: opened.store)
                    default:
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
        } catch {
            NSLog("cb21: cannot open History: \(error)")
        }
    }
}
