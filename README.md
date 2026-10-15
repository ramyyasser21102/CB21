<p align="center">
  <img src="docs/assets/cb21.png" alt="cb21 app icon" width="160">
</p>

# cb21

A free, native clipboard history manager for macOS. It lives in the menu bar and remembers what you copy, so you can use anything again without copying it twice.

No account, no ads, no network access, no telemetry.

## Features

- **Remembers everything you copy**: text, rich text, images, files and links.
- **Menu bar list** of your 10 most recent copies. Click one to copy it back.
- **History window** with the full list. Select several clips with Shift or Cmd-click, then delete them. Each row has a Copy button that copies the clip, makes it the most recent and closes the window so you can paste straight away.
- **Global shortcuts** (all optional, you choose the keys): open the History window, open the menu bar list, and pause or resume capture.
- **Details for every clip**: select a clip in the History window to see it in full next to the list. Text shows with character, word and line counts; images with their size and format; PDFs with a first-page preview, page count and title; files with a thumbnail, size, kind and modified date; links with their host. Each row also shows when it was copied, how big it is and which app it came from.
- **Pause capture** for 5 minutes, 15 minutes or until you resume, so you can copy a secret without it being saved.
- **Skips sensitive copies** that apps mark as concealed, such as password managers.
- **You set the limits**: maximum number of clips (default 100) and maximum storage (default 100 MB). The least recently used clips go first.
- **Launch at login**, off by default.

## Install

1. Download `cb21-<version>.zip` from the [Releases](../../releases) page and unzip it.
2. Drag `cb21.app` into your Applications folder.
3. Open it. cb21 isn't notarized by Apple, because it is a free project without a paid developer account, so macOS blocks the first launch. Either:
   - open **System Settings > Privacy & Security**, scroll down, and click **Open Anyway** next to cb21; or
   - run `xattr -dr com.apple.quarantine /Applications/cb21.app` in Terminal and open it again.
4. On macOS 15.4 and later, allow cb21 to read the clipboard if asked (**System Settings > Privacy & Security > Paste from Other Apps**).

Requires macOS 14 (Sonoma) or later.

## Build from source

You need Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/check.sh           # runs the tests and builds the app
scripts/build-release.sh   # builds dist/cb21-<version>.zip
```

The app logic lives in the `CB21Core` Swift package (no UI, covered by tests). The `App/` folder holds the menu bar, History window and Settings. The Xcode project is generated from `project.yml` and isn't committed.

## Privacy

cb21 makes no network connections. For each new clip it also remembers the name of the app that was in front when you copied (the "source app"), stored only on your Mac with the rest of your History. History is stored on your Mac in `~/Library/Application Support/cb21/` and **is not encrypted**, so anyone with access to your account can read it. Deleting a clip, or using Clear all, removes it from the database (with SQLite `secure_delete` on) and deletes its image files.

cb21 skips copies that apps mark as concealed or transient. Use Pause for anything else you don't want kept.

## Project notes

- [`user-stories.md`](user-stories.md): what cb21 does and what is left out of v1.
- [`CONTEXT.md`](CONTEXT.md): the terms used in the code and docs.
- [`docs/adr/`](docs/adr): architecture decisions.
- [`docs/plan.md`](docs/plan.md): the development plan and status.
