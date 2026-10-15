# Clipboard Hero

A lightweight, native clipboard history for macOS (Apple Silicon). It lives in the menu bar and opens a Spotlight-style search panel from a global hotkey.

Built with Swift, AppKit and SwiftUI. No Electron, no web view: about 12 MB of memory and ~0% CPU when idle.

## Features

- [x] Menu bar icon, no Dock icon
- [x] Text and image clipboard history, newest first
- [x] Search panel opened with a global hotkey (default `⌥Space`), image previews
- [x] Menu bar menu: last 5 items, app version
- [x] Settings: hotkey, history size, launch at login, clear history
- [x] Skips items that password managers mark as concealed

## Install

Download `ClipboardHero.zip` from [Releases](https://github.com/silveiralsv/clipboard-hero/releases), unzip it and move `ClipboardHero.app` to `/Applications`.

The app is not notarized by Apple, so macOS blocks the first launch with "Apple could not verify…". Click **Done** (not "Move to Trash"), then allow it once with:

```sh
xattr -dr com.apple.quarantine /Applications/ClipboardHero.app
```

Or, without the terminal: **System Settings › Privacy & Security**, scroll down and click **Open Anyway** next to ClipboardHero.

## Build from source

Needs macOS 14+ on Apple Silicon and the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is not required.

```sh
./scripts/bundle.sh
open build/ClipboardHero.app
```

Run the tests with `./scripts/test.sh`.

History is stored in `~/Library/Application Support/ClipboardHero/`.

## License

[MIT](LICENSE)
