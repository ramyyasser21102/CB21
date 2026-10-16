import CB21Core
import Foundation
import Observation

/// What CB21 knows about its access to Desktop, Documents and Downloads.
///
/// Nothing here probes a folder by itself unless the user already pressed Allow in an earlier run: probing a folder
/// macOS has never been asked about is what shows its permission prompt.
@MainActor
@Observable
final class FolderAccessModel {
    private(set) var states: [ProtectedFolder: FolderAccessState] = [:]
    /// Bumps whenever a state changes, so views that depend on it can reload.
    private(set) var revision = 0
    private(set) var isChecking = false

    private let settings: SettingsModel

    init(settings: SettingsModel) {
        self.settings = settings
    }

    func state(for folder: ProtectedFolder) -> FolderAccessState? {
        states[folder]
    }

    var allAllowed: Bool {
        ProtectedFolder.allCases.allSatisfy { states[$0] == .allowed || states[$0] == .missing }
    }

    /// At launch, only if the user has pressed Allow before. macOS has decided by then, so this can't prompt.
    func quietCheckAtLaunch() {
        guard settings.values.folderAccessRequested else { return }
        Task { await check(ProtectedFolder.allCases) }
    }

    /// Asks macOS for the folders, one after another, so each prompt appears while the user is looking.
    func requestAccess(for folders: [ProtectedFolder] = ProtectedFolder.allCases) async {
        settings.update { $0.folderAccessRequested = true }
        await check(folders)
    }

    private func check(_ folders: [ProtectedFolder]) async {
        isChecking = true
        defer { isChecking = false }
        for folder in folders {
            // The listing waits while macOS shows its prompt, so it must not run on the main thread.
            let state = await Task.detached(priority: .userInitiated) { FolderAccess.check(folder) }.value
            if states[folder] != state {
                states[folder] = state
                revision += 1
            }
        }
    }
}
