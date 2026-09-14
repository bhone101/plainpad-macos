# PlainPad

![PlainPad icon](PlainPad/Resources/AppIcon.iconset/icon_128x128.png)

A small, offline, native macOS plain-text editor inspired by classic Notepad. Built with Swift, AppKit, `NSDocument`, and `NSTextView`. No web components, dependencies, telemetry, or paid developer account.

## Quick start

```sh
git clone git@github.com:bhone101/plainpad-macos.git
cd plainpad-macos/PlainPad
./scripts/build.sh
open build/PlainPad.app
```

This is a private repository; cloning requires an account with access. Build artifacts are generated locally and excluded from version control.

## Open the app

The build script produces `PlainPad/build/PlainPad.app`. Commands below run from the `PlainPad` directory unless stated otherwise.

Double-click it in Finder, or run:

```sh
open build/PlainPad.app
```

Launch opens a focused blank document. Open files with File → Open, Finder → Open With → PlainPad, or drop files on the app or an editor window. Multiple documents use separate windows. The app remains running after the last window closes; clicking its Dock icon opens a new document.

## Build

Requires macOS 13 or newer and Apple's Swift compiler/macOS SDK. The local build is ad-hoc signed for use on this Mac, not notarized for distribution.

From the repository root, enter the application directory first:

```sh
cd PlainPad
```

Then build:

```sh
./scripts/build.sh
open build/PlainPad.app
```

The script builds for the current Mac's architecture. It uses only Command Line Tools. To build for another architecture, use Xcode on a suitable Mac or adjust the compiler target.

With full Xcode installed, open `PlainPad/PlainPad.xcodeproj`, select the shared **PlainPad** scheme, and choose Run. The project includes an application target and an XCTest target, with local ad-hoc signing configured. No team is required. From Terminal:

```sh
xcodebuild -project PlainPad.xcodeproj -scheme PlainPad -configuration Debug -derivedDataPath build/Xcode build
xcodebuild -project PlainPad.xcodeproj -scheme PlainPad -configuration Debug -derivedDataPath build/Xcode test
```

The Xcode-built app is `build/Xcode/Build/Products/Debug/PlainPad.app`. The project generator (`scripts/generate-project.py`) is provided for reproducibility; it requires only Python 3 and is not needed for ordinary builds.

## Editing and files

- Literal plain text, Unicode, tabs, normal Mac selection/navigation, context menu, undo/redo, and plain-text paste.
- Smart quotes, smart dashes, smart insert/delete, automatic correction, completion, and substitutions are disabled by default.
- New/Open/Open Recent/Save/Save As, native close/quit confirmation, native printing and page setup.
- `.txt`, `.log`, `.csv`, `.md`, other text extensions, and extensionless files are accepted. Suggested new-file extension is `.txt`; Save As permits another extension.
- Safe writes use `NSDocument`. A failed save retains the text and modified state.
- Disk modification dates are checked every two seconds. A changed-disk notice appears in the status bar. File → Reload from Disk reloads explicitly; modified documents ask before discarding edits. Saving compares the actual disk bytes with the last-read/saved bytes and offers Cancel, Overwrite, or Reload if they differ. A missing disk file also triggers this decision. As with ordinary desktop editors, another writer can still race the final check and write transaction.
- File associations register PlainPad as an alternate handler; the build does not change defaults.

## Encoding and line endings

Format → Encoding selects UTF-8, UTF-8 with BOM, UTF-16 LE/BE with BOM, or Windows-1252. Changing encoding marks the document modified. Save As reports the current encoding; set it in Format before saving.

Opening detects BOMs first, then strictly decodes UTF-8. Invalid Unicode prompts for Windows-1252 or cancellation; malformed BOM-tagged Unicode remains an error. Files containing null characters are rejected as unsupported binary content. Windows-1252 uses a byte-preserving table, including its five undefined control-code positions. Unsupported characters cannot be silently substituted: saving offers UTF-8 or cancellation.

Uniform LF, CRLF, and CR files retain their convention. Typing and pasted newline sequences use that convention. Mixed files keep existing newline bytes, and new Return characters use LF. Format → Normalize Line Endings explicitly converts the whole file in one undoable operation. Trailing whitespace and final-newline presence are preserved unless edited. An empty/new file defaults to UTF-8 without BOM and LF.

The status bar reports the document's retained line-ending convention (including Mixed), encoding, zoom, and insertion/selection-start position. Its convention remains selected when the document becomes empty.

## Display and navigation

Format → Font opens the native font panel. Word wrap, font, and status-bar visibility persist across launches. Zoom is per window. Display changes do not alter saved text or mark documents modified. Colors follow the system appearance.

Line numbers count logical lines separated by CR, LF, or CRLF, starting at 1, including an empty line after a final separator. Columns count Unicode extended grapheme clusters from 1: an emoji sequence or a combining character sequence counts as one; a tab counts as one. A selection reports its start. Visual wrapping never changes logical line numbers. The line index updates only the affected lines; status changes do not rescan the whole document.

Find/Replace searches literal, non-overlapping text with Match Case and Wrap Around controls. Replace acts on a selected match, then finds the next. Replace All is one undo action and never recursively searches inserted text. Empty searches are rejected. Go to Line validates the requested logical line.

Edit → Time and Date inserts a locale-formatted local timestamp. F5 also invokes this command when macOS delivers that function key (Fn-F5 may be necessary). Opening a file whose first line is exactly `.LOG` appends a newline, a timestamp, and a newline once, moves the cursor to the end, and marks it modified. This is not automatically saved. Reloading an already-open document does not append another timestamp.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| New / Open / Save | Command-N / O / S |
| Save As | Command-Shift-S |
| Close / Quit / Print | Command-W / Q / P |
| Page Setup | Command-Shift-P |
| Undo / Redo | Command-Z / Command-Shift-Z |
| Cut / Copy / Paste | Command-X / C / V |
| Select All | Command-A |
| Find | Command-F |
| Next / Previous | Command-G / Command-Shift-G |
| Replace | Command-Option-F |
| Go to Line | Command-L |
| Zoom In / Out / Reset | Command-Plus / Minus / 0 |
| Time and Date | F5 (or Fn-F5) |

## Automated verification

```sh
./scripts/test.sh
./scripts/test-integration.sh
```

The first runs nine portable test groups: Unicode/BOM byte round trips, strict decoding errors, all nonzero Windows-1252 bytes and unsupported Unicode, line-ending/whitespace integrity, literal search and replacement, logical line boundaries, 3,000 deterministic randomized incremental-index edits, `.LOG`, and an 11 MB text fixture. These same cases are included in the Xcode XCTest target.

The second requires an active macOS GUI login and briefly creates native windows. It checks window registration/visibility, modified-state tracking, independent document undo, save/reopen byte integrity, save failures, display-only changes, `.LOG`, external-change detection, a print operation, mixed-line-ending normalization undo/redo, and an 11 MB editor load/edit. It uses its own temporary directory, restores the wrap setting, and deletes test files on success.

For a short launch check that exits automatically:

```sh
build/PlainPad.app/Contents/MacOS/PlainPad --smoke-test
```

See [`PlainPad/VERIFICATION.md`](PlainPad/VERIFICATION.md) for what actually ran in this environment and the remaining manual checks.

## Limits

- This machine has Command Line Tools but no full Xcode. Direct Swift builds and standalone tests can run; the Xcode XCTest target cannot be executed here until Xcode is installed and selected with `xcode-select`.
- Native UI affordances are used throughout, but Finder dragging, actual print-dialog/PDF output, VoiceOver, system appearance switching, and every keyboard layout require the manual checks below.
- Files above 64 MB prompt before loading. This is an in-memory editor, not a streaming multi-gigabyte viewer. Find/Replace All scan the document on demand; very long logical lines make layout and column counting more expensive.
- Zoom is not persisted. There is no rich text, highlighting, regex search, or recovery autosave; save your work through the standard File commands.

## Source map

`Sources/TextModel.swift` contains pure encoding, line endings, search, navigation, and log behavior. `Document.swift` owns file lifecycle and printing; `Editor.swift` owns AppKit editing/display; `FindController.swift` owns search UI; `Preferences.swift` stores display preferences; `App.swift` supplies startup and menus. The original icon is generated by vector drawing code in `scripts/make-icon.swift`; PNG variants and the `.icns` are included.
