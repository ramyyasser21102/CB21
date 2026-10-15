import AppKit
import Foundation
import CB21Core

/// Owns the History store and polls the system pasteboard.
@MainActor
final class CaptureService {
    static let shared = CaptureService()

    let model = HistoryModel()
    let settings = SettingsModel()
    private let hotKeys = GlobalHotKeys()
    private var historyHotKeyID: UInt32?
    private var pauseHotKeyID: UInt32?
    private var menuHotKeyID: UInt32?
    /// Opens the menu bar menu. Set by the app once the status item exists.
    var openMenu: (() -> Void)?
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

    /// Binds (or, with nil, clears) the global shortcut that toggles the History window.
    /// Returns a message to show when the shortcut was refused.
    func setHistoryShortcut(_ shortcut: Shortcut?) -> String? {
        setShortcut(shortcut, current: settings.values.historyShortcut,
                    others: [settings.values.pauseShortcut, settings.values.menuShortcut],
                    id: \.historyHotKeyID, register: registerHistory) { $0.historyShortcut = shortcut }
    }

    /// Binds (or, with nil, clears) the global shortcut that pauses or resumes capture.
    func setPauseShortcut(_ shortcut: Shortcut?) -> String? {
        setShortcut(shortcut, current: settings.values.pauseShortcut,
                    others: [settings.values.historyShortcut, settings.values.menuShortcut],
                    id: \.pauseHotKeyID, register: registerPause) { $0.pauseShortcut = shortcut }
    }

    /// Binds (or, with nil, clears) the global shortcut that opens the menu bar list.
    func setMenuShortcut(_ shortcut: Shortcut?) -> String? {
        setShortcut(shortcut, current: settings.values.menuShortcut,
                    others: [settings.values.historyShortcut, settings.values.pauseShortcut],
                    id: \.menuHotKeyID, register: registerMenu) { $0.menuShortcut = shortcut }
    }

    private func registerMenu(_ shortcut: Shortcut) -> UInt32? {
        hotKeys.register(shortcut) { [weak self] in self?.openMenu?() }
    }

    private func setShortcut(
        _ shortcut: Shortcut?,
        current: Shortcut?,
        others: [Shortcut?],
        id: ReferenceWritableKeyPath<CaptureService, UInt32?>,
        register: (Shortcut) -> UInt32?,
        save: (inout SettingsValues) -> Void
    ) -> String? {
        if let shortcut, let problem = ShortcutValidator.validate(shortcut, takenByOtherActions: others.compactMap { $0 }) {
            return Self.message(for: problem)
        }
        if let previous = self[keyPath: id] { hotKeys.unregister(previous) }
        self[keyPath: id] = nil
        if let shortcut {
            guard let newID = register(shortcut) else {
                if let current { self[keyPath: id] = register(current) }
                return "Another app already uses this shortcut. Choose a different one."
            }
            self[keyPath: id] = newID
        }
        settings.update(save)
        return nil
    }

    private func registerPause(_ shortcut: Shortcut) -> UInt32? {
        hotKeys.register(shortcut) { [weak self] in self?.togglePause() }
    }

    /// Pauses capture for the given time, or resumes it when `duration` is nil.
    func setPause(_ duration: PauseDuration?) {
        guard let engine else { return }
        Task {
            if let duration { await engine.pause(duration) } else { await engine.resume() }
            model.setPaused(await engine.isPaused())
        }
    }

    func togglePause() {
        setPause(model.isPaused ? nil : .untilResumed)
    }

    private func registerHistory(_ shortcut: Shortcut) -> UInt32? {
        hotKeys.register(shortcut) { [weak self] in
            guard let self else { return }
            HistoryWindowController.shared.toggle(service: self)
        }
    }

    private static func message(for problem: ShortcutProblem) -> String {
        switch problem {
        case .needsModifier: "Include at least one of ⌘, ⌃ or ⌥."
        case .systemReserved: "macOS or common apps already use this shortcut. Choose a different one."
        case .alreadyUsed: "cb21 already uses this shortcut for something else."
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
            if let saved = settings.values.historyShortcut {
                historyHotKeyID = registerHistory(saved)
            }
            if let saved = settings.values.pauseShortcut {
                pauseHotKeyID = registerPause(saved)
            }
            if let saved = settings.values.menuShortcut {
                menuHotKeyID = registerMenu(saved)
            }
            let model = self.model
            if opened.recoveredFrom != nil { model.post(.databaseRecovered) }
            task = Task {
                _ = try? await opened.store.sweepOrphanedImageFiles()
                await model.refresh(from: opened.store)
                while !Task.isCancelled {
                    model.setPasteboardAccessDenied(pasteboard.isAccessDenied)
                    model.setPaused(await engine.isPaused())
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
