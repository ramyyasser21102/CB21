# Search lives in the native menu, filtered from memory

The menu bar list stays a native `NSMenu`, with a search field embedded in its first item, instead of becoming a custom popover. It looks and behaves like a Mac menu, and keeps ⌘1 to ⌘9 as ordinary key equivalents. The cost is that a menu that is open doesn't run queued background work (the same reason repeated shortcut presses piled up), so the menu can't ask the database as you type. It filters a copy of each Clip's searchable text kept in memory, and every menu change while it is open must be synchronous.

## Considered Options

- A custom popover under the icon: full control over typing, arrow keys and layout, and a star button on each row. Rejected for now because it replaces the familiar menu and the open-menu shortcut behaviour.
- A text field in a menu item can fight the menu over arrow keys, Return and Escape. The plan starts with a small spike to check this before building on it; if it fails, the popover is the fallback.
