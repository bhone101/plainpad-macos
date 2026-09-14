import AppKit

final class PlainTextView: NSTextView {
    var openFiles: (([URL]) -> Void)?
    override func changeFont(_ sender: Any?) {
        if let manager = sender as? NSFontManager { Preferences.shared.font = manager.convert(Preferences.shared.font) }
    }
    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) { return .copy }
        return super.draggingEntered(sender)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            openFiles?(urls); return true
        }
        return super.performDragOperation(sender)
    }
}

final class EditorController: NSWindowController, NSTextViewDelegate, NSTextStorageDelegate, NSMenuItemValidation {
    let textView = PlainTextView(frame: .zero)
    private let scroll = NSScrollView()
    private let status = NSTextField(labelWithString: "")
    private var statusHeight: NSLayoutConstraint!
    private var index = LineIndex()
    private var zoom: CGFloat = 1
    private var loading = false
    private var preferenceObserver: NSObjectProtocol?
    private var findController: FindController?
    private unowned let owningDocument: PlainDocument
    var pad: PlainDocument { owningDocument }

    init(document: PlainDocument) {
        owningDocument = document
        let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 840,height: 580), styleMask: [.titled,.closable,.miniaturizable,.resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.minSize = NSSize(width: 420,height: 260); window.center()
        window.setFrameAutosaveName("PlainPadDocument")
        window.tabbingMode = .disallowed
        let content = window.contentView!
        scroll.translatesAutoresizingMaskIntoConstraints = false
        status.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll); content.addSubview(status)
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.setAccessibilityLabel("Document status")
        statusHeight = status.heightAnchor.constraint(equalToConstant: 25)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor), scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: status.topAnchor),
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),status.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),status.bottomAnchor.constraint(equalTo: content.bottomAnchor),statusHeight
        ])
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.borderType = .noBorder
        scroll.documentView = textView
        textView.isRichText = false; textView.importsGraphics = false; textView.allowsUndo = true
        textView.smartInsertDeleteEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false; textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false; textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false; textView.isAutomaticDataDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false; textView.isGrammarCheckingEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.textContainerInset = NSSize(width: 8,height: 10)
        textView.isVerticallyResizable = true; textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,height: CGFloat.greatestFiniteMagnitude)
        textView.usesFindPanel = false
        textView.setAccessibilityLabel("Plain text editor")
        textView.registerForDraggedTypes([.fileURL])
        textView.openFiles = { urls in for url in urls { NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _,_,error in if let error { NSApp.presentError(error) } } } }
        loadText(document.model.text)
        textView.delegate = self; textView.textStorage?.delegate = self
        preferenceObserver = NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in self?.applyPreferences() }
        applyPreferences()
        window.initialFirstResponder = textView
        window.makeFirstResponder(textView)
        if document.model.text.hasPrefix(".LOG") { textView.setSelectedRange(NSRange(location: textView.string.utf16.count,length: 0)); textView.scrollRangeToVisible(textView.selectedRange()) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    deinit { if let preferenceObserver { NotificationCenter.default.removeObserver(preferenceObserver) } }
    func loadText(_ text: String) {
        loading = true; textView.string = text; index = LineIndex(text); loading = false
        updateStatus()
    }
    func applyPreferences() {
        let preferences = Preferences.shared
        let font = preferences.font
        textView.font = NSFont(descriptor: font.fontDescriptor,size: font.pointSize*zoom)
        textView.textColor = .textColor; textView.backgroundColor = .textBackgroundColor
        scroll.hasHorizontalScroller = !preferences.wrap
        textView.isHorizontallyResizable = !preferences.wrap
        textView.autoresizingMask = preferences.wrap ? [.width] : []
        textView.textContainer?.widthTracksTextView = preferences.wrap
        textView.textContainer?.containerSize = NSSize(width: preferences.wrap ? max(1,scroll.contentSize.width) : CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        if preferences.wrap { textView.setFrameSize(NSSize(width: scroll.contentSize.width,height: max(scroll.contentSize.height,textView.frame.height))) }
        status.isHidden = !preferences.status; statusHeight.constant = preferences.status ? 25 : 0
        updateStatus()
    }
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard !loading, editedMask.contains(.editedCharacters) else { return }
        index.update(newText: textStorage.mutableString, editedRange: editedRange, delta: delta)
    }
    func textDidChange(_ notification: Notification) { updateStatus() }
    func textViewDidChangeSelection(_ notification: Notification) { updateStatus() }
    func undoManager(for view: NSTextView) -> UndoManager? { pad.undoManager }
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard !loading, pad.undoManager?.isUndoing != true, pad.undoManager?.isRedoing != true, let replacementString, pad.ending != .mixed else { return true }
        let normalized = pad.ending.normalize(replacementString)
        if normalized != replacementString {
            replace(range: affectedCharRange, with: normalized, action: "Typing")
            return false
        }
        return true
    }
    func updateStatus() {
        guard isWindowLoaded else { return }
        let offset = min(textView.selectedRange().location,(textView.string as NSString).length)
        let line = index.line(at: offset)
        // Columns count extended grapheme clusters; a tab is one column.
        let prefix = (textView.string as NSString).substring(with: NSRange(location: index.starts[line], length: max(0,offset-index.starts[line])))
        status.stringValue = "Ln \(line+1), Col \(prefix.count+1)    \(Int(zoom*100))%    \(pad.model.encoding.rawValue)    \(pad.ending.rawValue)" + (pad.diskChanged ? "    Disk changed — File → Reload from Disk" : "")
    }
    func replace(range: NSRange, with value: String, action: String) {
        guard textView.shouldChangeText(in: range, replacementString: value) else { return }
        textView.breakUndoCoalescing()
        textView.textStorage?.replaceCharacters(in: range, with: value)
        textView.didChangeText()
        textView.setSelectedRange(NSRange(location: range.location+value.utf16.count,length: 0))
        pad.undoManager?.setActionName(action)
        textView.breakUndoCoalescing()
        textView.scrollRangeToVisible(textView.selectedRange())
    }
    @objc func showFind(_ sender: Any?) { showSearch(replace: false) }
    @objc func showReplace(_ sender: Any?) { showSearch(replace: true) }
    private func showSearch(replace: Bool) {
        if findController == nil { findController = FindController(editor: self) }
        findController?.show(replace: replace)
    }
    @objc func findNext(_ sender: Any?) { if let findController { findController.find(backward: false) } else { showFind(sender) } }
    @objc func findPrevious(_ sender: Any?) { if let findController { findController.find(backward: true) } else { showFind(sender) } }
    @objc func goToLine(_ sender: Any?) {
        let alert = NSAlert(); alert.messageText = "Go to Line"; alert.informativeText = "Enter a logical line from 1 to \(index.starts.count)."
        let field = NSTextField(frame: NSRect(x: 0,y: 0,width: 240,height: 24)); field.placeholderString = "Line number"; field.setAccessibilityLabel("Line number")
        alert.accessoryView = field; alert.addButton(withTitle: "Go"); alert.addButton(withTitle: "Cancel"); alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let number = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), let offset = index.offset(forLine: number) else {
            let a = NSAlert(); a.messageText = "Invalid line number"; a.informativeText = "Use a whole number from 1 to \(index.starts.count)."; a.runModal(); return
        }
        window?.makeFirstResponder(textView); textView.setSelectedRange(NSRange(location: offset,length: 0)); textView.scrollRangeToVisible(textView.selectedRange())
    }
    @objc func insertTimeDate(_ sender: Any?) { replace(range: textView.selectedRange(), with: LogEntry.timestamp(), action: "Insert Time and Date") }
    @objc func toggleWrap(_ sender: Any?) { Preferences.shared.wrap.toggle() }
    @objc func toggleStatus(_ sender: Any?) { Preferences.shared.status.toggle() }
    @objc func chooseFont(_ sender: Any?) { NSFontManager.shared.setSelectedFont(Preferences.shared.font,isMultiple: false); NSFontManager.shared.orderFrontFontPanel(sender) }
    @objc func changeFont(_ sender: Any?) {
        guard let manager = sender as? NSFontManager else { return }
        Preferences.shared.font = manager.convert(Preferences.shared.font)
    }
    @objc func zoomIn(_ sender: Any?) { zoom = min(4,zoom+0.1); applyPreferences() }
    @objc func zoomOut(_ sender: Any?) { zoom = max(0.3,zoom-0.1); applyPreferences() }
    @objc func resetZoom(_ sender: Any?) { zoom = 1; applyPreferences() }
    @objc func setEncoding(_ sender: NSMenuItem) {
        let encoding = TextEncoding.allCases[sender.tag]
        guard pad.model.encoding != encoding else { return }
        let previous = pad.model.encoding
        pad.undoManager?.registerUndo(withTarget: self) { target in let item = NSMenuItem(); item.tag = TextEncoding.allCases.firstIndex(of: previous)!; target.setEncoding(item) }
        pad.model.encoding = encoding; pad.updateChangeCount(.changeDone); updateStatus()
    }
    @objc func setEnding(_ sender: NSMenuItem) {
        let ending = LineEnding.allCases[sender.tag]
        let newText = ending.normalize(textView.string)
        let previous = pad.ending
        pad.undoManager?.beginUndoGrouping()
        // Set the convention first so the delegate does not normalize back to the old one.
        pad.ending = ending
        pad.undoManager?.registerUndo(withTarget: self) { $0.restoreEnding(previous) }
        if newText != textView.string { replace(range: NSRange(location: 0,length: textView.string.utf16.count), with: newText, action: "Normalize Line Endings") }
        pad.undoManager?.endUndoGrouping(); updateStatus()
    }
    private func restoreEnding(_ value: LineEnding) {
        let old = pad.ending; pad.undoManager?.registerUndo(withTarget: self) { $0.restoreEnding(old) }; pad.ending = value; updateStatus()
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleWrap): menuItem.state = Preferences.shared.wrap ? .on : .off
        case #selector(toggleStatus): menuItem.state = Preferences.shared.status ? .on : .off
        case #selector(setEncoding): menuItem.state = pad.model.encoding == TextEncoding.allCases[menuItem.tag] ? .on : .off
        case #selector(setEnding): menuItem.state = pad.ending == LineEnding.allCases[menuItem.tag] ? .on : .off
        default: break
        }; return true
    }
}
