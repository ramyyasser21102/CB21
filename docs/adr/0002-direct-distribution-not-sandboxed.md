# Free direct distribution, unsandboxed and not notarized

CB21 v1 ships outside the Mac App Store, unsandboxed, ad-hoc signed and not notarized, because there is no paid Apple Developer account and the app is free. A background pasteboard watcher, a global shortcut and launch-at-login are least friction without the sandbox. Moving to the App Store or adding notarization later is possible, but would need a Developer account and some rework of those pieces.

## Consequences

- macOS Gatekeeper warns about a downloaded copy. The README must explain how to open it (right-click, Open, or clearing the quarantine flag).
- Building from source needs only Xcode and works without any account.
