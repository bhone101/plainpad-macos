import AppKit

final class FindController: NSWindowController {
    weak var editor: EditorController?
    let query = NSTextField(), replacement = NSTextField()
    let matchCase = NSButton(checkboxWithTitle: "Match case", target: nil, action: nil)
    let wrap = NSButton(checkboxWithTitle: "Wrap around", target: nil, action: nil)
    let message = NSTextField(labelWithString: "")
    init(editor: EditorController) {
        self.editor = editor
        let panel = NSPanel(contentRect: NSRect(x: 0,y: 0,width: 450,height: 220), styleMask: [.titled,.closable,.utilityWindow], backing: .buffered,defer: false)
        super.init(window: panel); panel.title = "Find and Replace"; panel.isFloatingPanel = true; panel.hidesOnDeactivate = true
        query.placeholderString = "Find literal text"; query.setAccessibilityLabel("Find text")
        replacement.placeholderString = "Replace with"; replacement.setAccessibilityLabel("Replacement text")
        wrap.state = .on
        let options = NSStackView(views: [matchCase,wrap]); options.orientation = .horizontal; options.spacing = 20
        let buttons = NSStackView(); buttons.orientation = .horizontal; buttons.spacing = 8
        for (title,action) in [("Previous",#selector(previous)),("Next",#selector(next)),("Replace",#selector(replaceCurrent)),("Replace All",#selector(replaceAll))] {
            let b = NSButton(title: title,target: self,action: action); b.bezelStyle = .rounded; buttons.addArrangedSubview(b)
            if title == "Next" { b.keyEquivalent = "\r" }
        }
        message.font = .systemFont(ofSize: 11); message.textColor = .secondaryLabelColor; message.setAccessibilityLabel("Search result")
        let stack = NSStackView(views: [query,replacement,options,buttons,message]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false; panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor,constant: 16),stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor,constant: -16),stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor,constant: 16), query.widthAnchor.constraint(equalTo: stack.widthAnchor),replacement.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        panel.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    func show(replace: Bool) {
        if let text = editor?.textView, text.selectedRange().length > 0 { query.stringValue = (text.string as NSString).substring(with: text.selectedRange()) }
        showWindow(nil); window?.makeKeyAndOrderFront(nil); window?.makeFirstResponder(query)
    }
    func find(backward: Bool) {
        guard let editor else { return }
        guard !query.stringValue.isEmpty else { message.stringValue = "Enter text to find."; showWindow(nil); return }
        let matches = TextSearch.matches(in: editor.textView.string,query: query.stringValue,matchCase: matchCase.state == .on)
        let selected = editor.textView.selectedRange()
        var found = backward ? matches.last(where: { NSMaxRange($0) <= selected.location }) : matches.first(where: { $0.location >= NSMaxRange(selected) })
        var wrapped = false
        if found == nil && wrap.state == .on { found = backward ? matches.last : matches.first; wrapped = found != nil }
        guard let found else { message.stringValue = matches.isEmpty ? "No matches." : "No more matches in this direction."; showWindow(nil); NSSound.beep(); return }
        editor.textView.setSelectedRange(found); editor.textView.scrollRangeToVisible(found)
        message.stringValue = "\(matches.count) match\(matches.count == 1 ? "" : "es")\(wrapped ? " · Wrapped around" : "")"
    }
    @objc func findNext(_ sender: Any?) { find(backward: false) }
    @objc func findPrevious(_ sender: Any?) { find(backward: true) }
    @objc func showFind(_ sender: Any?) { window?.makeFirstResponder(query) }
    @objc func showReplace(_ sender: Any?) { window?.makeFirstResponder(replacement) }
    @objc func next(_ sender: Any?) { find(backward: false) }
    @objc func previous(_ sender: Any?) { find(backward: true) }
    @objc func replaceCurrent(_ sender: Any?) {
        guard let editor, !query.stringValue.isEmpty else { message.stringValue = "Enter text to find."; return }
        let selection = editor.textView.selectedRange()
        let matches = TextSearch.matches(in: editor.textView.string,query: query.stringValue,matchCase: matchCase.state == .on)
        if matches.contains(selection) {
            editor.replace(range: selection,with: editor.pad.ending.normalize(replacement.stringValue),action: "Replace")
        }
        find(backward: false)
    }
    @objc func replaceAll(_ sender: Any?) {
        guard let editor, !query.stringValue.isEmpty else { message.stringValue = "Enter text to find."; return }
        if editor.textView.string.utf16.count > 20_000_000 {
            let a = NSAlert(); a.messageText = "Replace throughout this large document?"; a.informativeText = "This may take a moment and uses additional memory for undo."; a.addButton(withTitle: "Replace All"); a.addButton(withTitle: "Cancel")
            guard a.runModal() == .alertFirstButtonReturn else { return }
        }
        let (text,count) = TextSearch.replaceAll(in: editor.textView.string,query: query.stringValue,replacement: editor.pad.ending.normalize(replacement.stringValue),matchCase: matchCase.state == .on)
        if count > 0 { editor.replace(range: NSRange(location: 0,length: editor.textView.string.utf16.count),with: text,action: "Replace All") }
        message.stringValue = count == 0 ? "No matches." : "Replaced \(count) matches."
    }
}
