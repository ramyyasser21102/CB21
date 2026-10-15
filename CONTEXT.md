# cb21

A free, native macOS clipboard history manager. It remembers what the user copies so they can re-use it without copying it again.

## Language

**Clip**:
One copy event, holding every representation the source app put on the pasteboard.
_Avoid_: Item, entry, record

**Representation**:
One format of a Clip's content, such as plain text, rich text, image, file reference or link.
_Avoid_: Type, flavor

**History**:
The ordered collection of Clips cb21 currently keeps, most recently used first.
_Avoid_: Clipboard (that is the system pasteboard, not cb21's store)

**Capture**:
Recording a new copy event from the system pasteboard as a Clip.
_Avoid_: Save, log

**Recopy**:
Putting an existing Clip back on the system pasteboard. The Clip moves to the top of History and is not captured again.
_Avoid_: Paste, restore

**Duplicate**:
A copy whose content equals the Clip at the top of History. It is not stored again.

**Skipped copy**:
A copy that is never captured and leaves no trace, because the source app marked it Concealed or Transient, or because cb21 is paused.
_Avoid_: Ignored, filtered

**Source app**:
The app that was in front when a Clip was captured, kept as its name. Clips captured before this was recorded have none.
_Avoid_: Origin, owner

**Metadata**:
Facts about a Clip shown to the user, such as size, counts, dimensions, page count or source app. Worked out on demand, except the source app and capture time, which are stored.
_Avoid_: Properties, info

**Detail pane**:
The part of the History window that shows one selected Clip in full, with its Metadata.
_Avoid_: Inspector, preview pane

**Welcome**:
The first-run window that walks the user through clipboard access, launch at login, shortcuts and privacy. Always dark, black and white. It can be skipped and reopened.
_Avoid_: Onboarding, wizard, setup assistant

**History window**:
The floating panel showing the full History, where the user browses, selects and deletes Clips. The menu shows only the latest Clips.
_Avoid_: Popup, manager

**Pause**:
A user-set state in which copies are not captured, so the user can copy sensitive data that cb21 would otherwise keep. Copies made while paused are Skipped copies.
_Avoid_: Private mode, disable

**Clear all**:
Deleting every Clip in History, after confirmation.

**Limits**:
The two user-set caps on History: maximum number of Clips and maximum total storage. The oldest-used Clips are evicted first when either is exceeded.
_Avoid_: Quota, retention
