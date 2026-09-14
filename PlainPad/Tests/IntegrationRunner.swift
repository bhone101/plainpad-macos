import AppKit

@main struct IntegrationRunner {
    static func checkWindow(_ document: PlainDocument) throws {
        guard document.windowControllers.count == 1, document.windowControllers[0].window?.isVisible == true else {
            throw NSError(domain: "PlainPad.Integration", code: 2, userInfo: [NSLocalizedDescriptionKey: "Document must register and show its window"])
        }
        print("PASS: Document registers and shows its window")
    }
    static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        let controller = PlainDocumentController()
        let first = PlainDocument(); controller.addDocument(first); first.makeWindowControllers()
        let editor = first.editor!
        first.showWindows()
        try checkWindow(first)

        func check(_ condition: @autoclosure () -> Bool,_ name: String) throws {
            guard condition() else { throw NSError(domain: "PlainPad.Integration",code: 1,userInfo: [NSLocalizedDescriptionKey:name]) }
            print("PASS: \(name)")
        }
        func flush() { RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.03)) }
        editor.replace(range: NSRange(location: 0,length: 0),with: "hello 😀\nworld  \t",action: "Typing"); flush()
        try check(first.isDocumentEdited,"Typing marks document modified")
        let content = editor.textView.string
        editor.zoomIn(nil); editor.toggleWrap(nil); editor.toggleWrap(nil)
        try check(editor.textView.string == content,"Display changes preserve content")
        let second = PlainDocument(); controller.addDocument(second); second.makeWindowControllers()
        second.editor!.replace(range: NSRange(location: 0,length: 0),with: "independent",action: "Typing"); flush()
        editor.replace(range: NSRange(location: 0,length: content.utf16.count),with: "replacement",action: "Replace All"); flush()
        first.undoManager!.undo(); flush()
        try check(editor.textView.string == content,"Replace All undo restores content in one action")
        try check(second.editor!.textView.string == "independent","Documents and undo are independent")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PlainPad-Integration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir,withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("test.log")
        var saveDone = false; var saveError: Error?
        first.save(to: url,ofType: "public.plain-text",for: .saveAsOperation) { error in saveError = error; saveDone = true }
        while !saveDone { flush() }
        if let saveError { throw saveError }
        try check(!first.isDocumentEdited,"Successful save clears modified state")
        try check(tryData(first.model) == (try? Data(contentsOf: url)),"Native save preserves exact data")
        let reopened = PlainDocument(); try reopened.read(from: url,ofType: "public.plain-text"); reopened.makeWindowControllers()
        try check(reopened.editor!.textView.string == content,"Saved document reopens identically")
        editor.zoomOut(nil); editor.resetZoom(nil)
        try check(!first.isDocumentEdited,"Zoom does not mark saved document modified")
        editor.replace(range: NSRange(location: 0,length: 0),with: "edit",action: "Typing"); flush()
        do {
            try first.writeSafely(to: dir.appendingPathComponent("missing/subfolder/failure.txt"),ofType: "public.plain-text",for: .saveAsOperation)
            try check(false,"Save to unavailable destination should fail")
        } catch {
            try check(first.isDocumentEdited && editor.textView.string.hasPrefix("edit"),"Save failure retains text and modified state")
        }
        let logURL = dir.appendingPathComponent("journal.txt"); try Data(".LOG\r\nentry".utf8).write(to: logURL)
        let log = PlainDocument(); try log.read(from: logURL,ofType: "public.plain-text"); log.makeWindowControllers()
        try check(log.isDocumentEdited && log.editor!.textView.string.hasPrefix(".LOG\r\nentry\r\n"),"LOG open appends and marks modified")
        let logText = log.editor!.textView.string; log.editor!.applyPreferences()
        try check(log.editor!.textView.string == logText,"LOG does not repeat on view updates")
        try check((try? Data(contentsOf: logURL)) == Data(".LOG\r\nentry".utf8),"LOG is not automatically saved")
        let externallyChanged = Data("newer disk contents".utf8)
        try externallyChanged.write(to: url, options: .atomic)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2.1))
        try check(first.diskChanged, "External modification detected")
        let printOp = try first.printOperation(withSettings: [:])
        try check(printOp.view is NSTextView,"Native print operation created")
        let mixed = PlainDocument(); mixed.model.text = "a\r\nb\nc\r"; mixed.ending = .mixed; mixed.makeWindowControllers()
        let normalize = NSMenuItem(); normalize.tag = 0
        mixed.editor!.setEnding(normalize); flush()
        try check(mixed.editor!.textView.string == "a\nb\nc\n", "Explicit line-ending normalization")
        mixed.undoManager!.undo(); flush()
        try check(mixed.editor!.textView.string == "a\r\nb\nc\r" && mixed.ending == .mixed, "Undo normalization restores exact mixed endings")
        mixed.undoManager!.redo(); flush()
        try check(mixed.editor!.textView.string == "a\nb\nc\n" && mixed.ending == .lf, "Redo normalization")
        mixed.updateChangeCount(.changeCleared); mixed.close()
        let start = Date()
        editor.loadText(String(repeating: "0123456789 plain text\n",count: 500_000))
        editor.replace(range: NSRange(location: 0,length: 0),with: "x",action: "Typing")
        print("PASS: 11 MB editor load and edit (\(String(format: "%.3f", Date().timeIntervalSince(start)))s)")
        for document in [first,second,reopened,log] { document.updateChangeCount(.changeCleared); document.close() }
        try FileManager.default.removeItem(at: dir)
        print("All AppKit integration checks passed")
    }
}
