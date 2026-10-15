import Carbon.HIToolbox
import CB21Core

/// System-wide shortcuts through Carbon's `RegisterEventHotKey`. It needs no permissions, and it
/// fails when another app has already registered the same shortcut, which is how conflicts are found.
@MainActor
final class GlobalHotKeys {
    private struct Entry {
        let ref: EventHotKeyRef
        /// Asked at the moment of the key press. Returning false drops the press instead of queueing it.
        let isEnabled: () -> Bool
        let action: () -> Void
    }

    private var entries: [UInt32: Entry] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    /// Registers a shortcut. Returns an id to unregister it with, or nil if the system refused it.
    func register(_ shortcut: Shortcut, isEnabled: @escaping () -> Bool = { true }, action: @escaping () -> Void) -> UInt32? {
        installHandlerIfNeeded()
        let id = nextID
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x6362_3231), id: id) // 'cb21'
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode), Self.carbonModifiers(shortcut.modifiers), hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return nil }
        nextID += 1
        entries[id] = Entry(ref: ref, isEnabled: isEnabled, action: action)
        return id
    }

    func unregister(_ id: UInt32) {
        if let entry = entries.removeValue(forKey: id) {
            UnregisterEventHotKey(entry.ref)
        }
    }

    fileprivate func accepts(_ id: UInt32) -> Bool {
        entries[id]?.isEnabled() ?? false
    }

    fileprivate func fire(_ id: UInt32) {
        entries[id]?.action()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let manager = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
            let id = hotKeyID.id
            // Carbon delivers this on the main thread. Deciding here, before any hop to a queue, is what lets a
            // press made while the menu is open be dropped instead of waiting in line behind it.
            guard MainActor.assumeIsolated({ manager.accepts(id) }) else { return noErr }
            DispatchQueue.main.async { MainActor.assumeIsolated { manager.fire(id) } }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    static func carbonModifiers(_ m: ShortcutModifiers) -> UInt32 {
        var flags: UInt32 = 0
        if m.contains(.command) { flags |= UInt32(cmdKey) }
        if m.contains(.control) { flags |= UInt32(controlKey) }
        if m.contains(.option) { flags |= UInt32(optionKey) }
        if m.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}
