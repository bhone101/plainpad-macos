import AppKit
import UniformTypeIdentifiers

final class PlainDocumentController: NSDocumentController {
    override func documentClass(forType typeName: String) -> AnyClass? { PlainDocument.self }
    override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        let document = PlainDocument(); document.fileType = typeName; return document
    }
    override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> NSDocument {
        let document = PlainDocument(); document.fileType = typeName; document.fileURL = url
        try document.read(from: url, ofType: typeName); return document
    }
    override var defaultType: String? { "public.plain-text" }
    override func typeForContents(of url: URL) throws -> String { "public.plain-text" }
    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        openPanel.allowedContentTypes = []; openPanel.allowsOtherFileTypes = true
        return super.runModalOpenPanel(openPanel, forTypes: nil)
    }
}

final class PlainDocument: NSDocument {
    var model = TextFile(text: "", encoding: .utf8)
    var ending: LineEnding = .lf
    var editor: EditorController?
    private var diskSnapshot: Data?
    private var externalChange = false
    private var watcher: Timer?
    private var lastDiskDate: Date?
    private var applyingLog = false
    override class var autosavesInPlace: Bool { false }
    override init() { super.init(); hasUndoManager = true }
    override func makeWindowControllers() {
        let controller = EditorController(document: self)
        editor = controller; addWindowController(controller)
        if applyingLog { updateChangeCount(.changeDone); applyingLog = false }
        watcher = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.checkDisk() }
    }
    override func close() { watcher?.invalidate(); watcher = nil; super.close() }
    override func read(from url: URL, ofType typeName: String) throws {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        if size > 64 * 1024 * 1024 {
            let alert = NSAlert(); alert.messageText = "Open this large text file?"
            alert.informativeText = "This file is \(size / 1_048_576) MB. Loading and editing may take time and substantial memory."
            alert.addButton(withTitle: "Open"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { throw CocoaError(.userCancelled) }
        }
        let data = try Data(contentsOf: url)
        var decoded: TextFile
        do { decoded = try TextFile.decode(data) }
        catch TextError.invalidEncoding {
            let alert = NSAlert(); alert.messageText = "Choose a text encoding"
            alert.informativeText = "This file could not be decoded as Unicode. Open it using Windows-1252, or cancel."
            alert.addButton(withTitle: "Open as Windows-1252"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { throw CocoaError(.userCancelled) }
            decoded = try TextFile.decode(data, legacy: true)
        }
        model = decoded; diskSnapshot = data; externalChange = false
        ending = LineEnding.detect(model.text)
        lastDiskDate = diskDate(url)
        // NSDocument invokes this for a deliberate open; view creation never appends a log.
        if editor == nil, let logged = LogEntry.appendOnOpen(model.text, timestamp: LogEntry.timestamp()) {
            model.text = logged; applyingLog = true
        }
        editor?.loadText(model.text)
    }
    override func data(ofType typeName: String) throws -> Data {
        if let editor { model.text = editor.textView.string }
        return try model.data()
    }
    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowedContentTypes = [UTType.plainText]
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        savePanel.message = "Encoding: \(model.encoding.rawValue). Choose encoding or normalize line endings in the Format menu."
        return true
    }
    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
        if let original = fileURL, original.standardizedFileURL == url.standardizedFileURL, let baseline = diskSnapshot {
            let current = try? Data(contentsOf: original)
            if current != baseline {
                let alert = NSAlert(); alert.messageText = "The file changed outside PlainPad"
                alert.informativeText = "Overwrite the current disk file with your edits, reload the disk version, or cancel to keep your edits without saving."
                alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Overwrite"); alert.addButton(withTitle: "Reload")
                switch alert.runModal() {
                case .alertSecondButtonReturn: break
                case .alertThirdButtonReturn: try reloadFromDisk(); throw CocoaError(.userCancelled)
                default: throw CocoaError(.userCancelled)
                }
            }
        }
        // Encoding is validated before NSDocument starts its safe-write transaction.
        do { _ = try data(ofType: typeName) }
        catch TextError.unrepresentable {
            let alert = NSAlert(); alert.messageText = "Save using UTF-8?"
            alert.informativeText = TextError.unrepresentable.localizedDescription
            alert.addButton(withTitle: "Use UTF-8"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { throw CocoaError(.userCancelled) }
            model.encoding = .utf8; editor?.updateStatus()
        }
        try super.writeSafely(to: url, ofType: typeName, for: saveOperation)
        diskSnapshot = try Data(contentsOf: url); lastDiskDate = diskDate(url); externalChange = false
        editor?.updateStatus()
    }
    private func diskDate(_ url: URL) -> Date? { (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate }
    private func checkDisk() {
        guard let url = fileURL else { return }
        let date = diskDate(url)
        guard date != lastDiskDate else { return }
        lastDiskDate = date
        externalChange = (try? Data(contentsOf: url)) != diskSnapshot
        editor?.updateStatus()
    }
    var diskChanged: Bool { externalChange }
    @objc func reloadDocument(_ sender: Any?) {
        if isDocumentEdited {
            let a = NSAlert(); a.messageText = "Discard your edits and reload?"; a.addButton(withTitle: "Cancel"); a.addButton(withTitle: "Reload")
            guard a.runModal() == .alertSecondButtonReturn else { return }
        }
        do { try reloadFromDisk() } catch { presentError(error) }
    }
    private func reloadFromDisk() throws {
        guard let url = fileURL else { return }
        try read(from: url, ofType: fileType ?? "public.plain-text")
        undoManager?.removeAllActions(); updateChangeCount(.changeCleared)
    }
    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey : Any]) throws -> NSPrintOperation {
        let info = printInfo.copy() as! NSPrintInfo
        info.dictionary().addEntries(from: printSettings)
        let width = info.paperSize.width-info.leftMargin-info.rightMargin
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        view.isRichText = false; view.string = editor?.textView.string ?? model.text
        view.font = Preferences.shared.font; view.textColor = .black; view.backgroundColor = .white
        view.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true
        view.layoutManager?.ensureLayout(for: view.textContainer!)
        let height = view.layoutManager!.usedRect(for: view.textContainer!).height+20
        view.setFrameSize(NSSize(width: width, height: max(10,height)))
        return NSPrintOperation(view: view, printInfo: info)
    }
}
