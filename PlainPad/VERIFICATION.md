# Verification record

Verified locally on 15 September 2026 with Apple Swift 6.4, an Apple Silicon Mac, the macOS SDK supplied with Command Line Tools, and a macOS 13 deployment target.

## Passed

- Optimized AppKit application build through `scripts/build.sh`.
- Ad-hoc code signature verification and Info.plist validation.
- Xcode project OpenStep property-list syntax validation. This is not an Xcode build.
- Application launch smoke test: one document, one registered and visible window, focused text editor. This test caught and verified the fix for an initial window-registration bug.
- All **9 core test groups** in `scripts/test.sh`, including 3,000 randomized edits around LF/CRLF/CR boundaries and an 11 MB fixture. The final model fixture test took approximately 0.09 seconds.
- All **19 native AppKit integration checks** in `scripts/test-integration.sh`: visible registered window; typing marks modified; display changes preserve content; Replace All undo in one action; independent documents; save clears modified; byte-exact native save; reopen equivalence; zoom leaves a saved document unmodified; failed save retains text and modified state; LOG appends/marks modified; no repeat on view changes; no automatic LOG save; external change detected; native print operation creation; line-ending normalization; exact mixed-ending undo; redo; and 11 MB editor load/edit.
- The final native 11 MB load/edit check took approximately **1.06 seconds**. This is a single local harness measurement, not a typing-latency or scrolling benchmark.

## Not run or not fully verified

Full Xcode and XCTest execution are unavailable: `xcodebuild` reports that the active developer directory is a Command Line Tools installation. Install full Xcode and select it with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` to execute the shared scheme's test target.

A standalone attempt to drive native close/overwrite dialogs programmatically stalled; that unreliable test was removed. These dialogs still require the manual checks below. The application uses NSDocument's native unsaved-close/quit lifecycle and its own explicit overwrite-conflict alert.

No claim is made that a complete Finder drag-and-drop, print-dialog/PDF, VoiceOver, or system-appearance UI pass has been completed. macOS denied Accessibility access to the attempted external UI inspection. Native window visibility and focus were instead verified inside the app's smoke test.

## Manual acceptance checks

| Check | Steps | Expected result | Status |
| --- | --- | --- | --- |
| Save/reopen | Type emoji, combining marks, tabs, trailing spaces, and several lines. Save, close, reopen. | Identical content, encoding, and final-newline state. | Native automated equivalent passed; full dialog path pending |
| Cancel unsaved close | Type into a new document. Command-W, then Cancel. Repeat through Command-Q. | Window stays open, all edits remain. | Manual pending |
| Failed save | Edit a file, make its destination unavailable or unwritable, and Save. | Clear error; edits and modified marker retained. | Unavailable-destination automated check passed; read-only dialog pending |
| Multiple documents | Open two files, edit each, undo in each. | Independent contents and undo histories. | Automated equivalent passed |
| Replace All undo | Replace every occurrence, then undo once. | Exact original text restored. | Automated equivalent passed |
| Display preferences | Save, change font/size, wrap and zoom; inspect modified indicator, save/reopen, relaunch. | Text unchanged; display changes do not mark modified; font/wrap/status persist. | Wrap/zoom automated; full font-panel and relaunch pass pending |
| Finder and dragging | Finder Open With → PlainPad; drop files on Dock icon and editor, including .log, .md, and extensionless files. | Separate text document opens; literal content shown. | Manual pending |
| Print/PDF | File → Page Setup, then Print; save through the PDF menu. | Paginated readable text with native paper/margin controls. | Operation creation passed; actual output pending |
| Appearance | Switch system light/dark appearance with editor and Find open. | Readable native colors and contrast. | Manual pending |
| Large text | Open ~10 MB, type at several positions, scroll, toggle wrap, search a very long line. | Usable response and unchanged content. | Automated 11 MB load/edit passed; interactive pass pending |
| External conflict | Edit locally, change same file in another editor, then Save in PlainPad. Test Cancel, Reload, Overwrite. | No silent overwrite; each decision honored. | Detection automated; dialog choices pending |
| Encoding failure | Type emoji, choose Windows-1252, Save. Cancel once, then choose UTF-8. | No lossy replacement; retained edits after cancellation. | Codec rejection automated; native dialog pending |
| Accessibility | Navigate menus and Find using keyboard and VoiceOver. Test F5/Fn-F5 and zoom shortcuts. | Labeled controls and usable keyboard focus. | Manual pending |
