import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var controller: PlainDocumentController!
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate(); app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
    func applicationWillFinishLaunching(_ notification: Notification) {
        controller = PlainDocumentController()
        buildMenus()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if controller.documents.isEmpty { controller.newDocument(nil) }
        for document in controller.documents {
            if document.windowControllers.isEmpty { document.makeWindowControllers() }
            document.showWindows()
            document.windowControllers.forEach { $0.window?.makeKeyAndOrderFront(nil) }
        }
        NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
                let documents = self.controller.documents
                print("Document classes: \(documents.map { String(describing: type(of: $0)) }); editor references: \(documents.map { ($0 as? PlainDocument)?.editor != nil })")
                let windows = documents.flatMap { $0.windowControllers.compactMap { $0.window } }
                let success = !documents.isEmpty && windows.contains { $0.isVisible && $0.firstResponder is NSTextView }
                print("Startup smoke test: documents=\(documents.count), windows=\(windows.count), visibleWindows=\(windows.filter { $0.isVisible }.count), focusedEditor=\(success)")
                fflush(stdout)
                NSApp.terminate(nil)
            }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if controller.documents.isEmpty { controller.newDocument(nil) }
            else { controller.documents.forEach { $0.showWindows() } }
        }
        return true
    }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @objc func showHelp(_ sender: Any?) {
        let a = NSAlert(); a.messageText = "PlainPad"
        a.informativeText = "A native plain-text editor.\n\nFormat provides encoding, line endings, word wrap, and font choices. View provides zoom and status. Edit provides literal find/replace, Go to Line, and time/date (F5).\n\nLine numbers count LF, CRLF, or CR document lines. Columns count Unicode grapheme clusters; tabs count as one column. Wrapping never changes line numbers.\n\nMixed line endings remain intact until you choose a normalization in Format. New lines in mixed documents use LF. External disk changes appear in the status bar; saving checks again before overwriting."
        a.runModal()
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "Open Recent" else { return }
        menu.removeAllItems()
        for url in controller.recentDocumentURLs {
            let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = url; item.toolTip = url.path; menu.addItem(item)
        }
        if !menu.items.isEmpty { menu.addItem(.separator()) }
        menu.addItem(NSMenuItem(title: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: ""))
    }
    @objc func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        controller.openDocument(withContentsOf: url, display: true) { _,_,error in if let error { NSApp.presentError(error) } }
    }
    private func buildMenus() {
        let root = NSMenu(); NSApp.mainMenu = root
        func menu(_ title: String) -> NSMenu {
            let item = NSMenuItem(); item.title = title
            let submenu = NSMenu(title: title); item.submenu = submenu; root.addItem(item); return submenu
        }
        func item(_ menu: NSMenu,_ title: String,_ action: Selector,_ key: String = "",_ modifiers: NSEvent.ModifierFlags = [.command]) {
            let item = NSMenuItem(title: title,action: action,keyEquivalent: key); item.keyEquivalentModifierMask = modifiers; menu.addItem(item)
        }
        let app = menu("PlainPad")
        item(app,"About PlainPad",#selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        app.addItem(.separator())
        let services = NSMenuItem(title: "Services",action: nil,keyEquivalent: ""); services.submenu = NSMenu(title: "Services"); app.addItem(services); NSApp.servicesMenu = services.submenu
        app.addItem(.separator()); item(app,"Hide PlainPad",#selector(NSApplication.hide(_:)),"h")
        item(app,"Hide Others",#selector(NSApplication.hideOtherApplications(_:)),"h",[.command,.option]); item(app,"Show All",#selector(NSApplication.unhideAllApplications(_:)))
        app.addItem(.separator()); item(app,"Quit PlainPad",#selector(NSApplication.terminate(_:)),"q")
        let file = menu("File")
        item(file,"New",#selector(NSDocumentController.newDocument(_:)),"n"); item(file,"Open…",#selector(NSDocumentController.openDocument(_:)),"o")
        let recent = NSMenuItem(title: "Open Recent",action: nil,keyEquivalent: "")
        let recentMenu = NSMenu(title: "Open Recent"); recentMenu.delegate = self
        recent.submenu = recentMenu; file.addItem(recent); item(recentMenu,"Clear Menu",#selector(NSDocumentController.clearRecentDocuments(_:)))
        file.addItem(.separator()); item(file,"Close",#selector(NSWindow.performClose(_:)),"w")
        item(file,"Save…",#selector(NSDocument.save(_:)),"s"); item(file,"Save As…",#selector(NSDocument.saveAs(_:)),"s",[.command,.shift])
        item(file,"Reload from Disk…",#selector(PlainDocument.reloadDocument(_:)))
        file.addItem(.separator()); item(file,"Page Setup…",#selector(NSDocument.runPageLayout(_:)),"p",[.command,.shift]); item(file,"Print…",#selector(NSDocument.printDocument(_:)),"p")
        let edit = menu("Edit")
        item(edit,"Undo",Selector(("undo:")),"z"); item(edit,"Redo",Selector(("redo:")),"z",[.command,.shift]); edit.addItem(.separator())
        item(edit,"Cut",#selector(NSText.cut(_:)),"x"); item(edit,"Copy",#selector(NSText.copy(_:)),"c"); item(edit,"Paste",#selector(NSText.paste(_:)),"v")
        item(edit,"Delete",#selector(NSText.delete(_:))); item(edit,"Select All",#selector(NSText.selectAll(_:)),"a"); edit.addItem(.separator())
        item(edit,"Find…",#selector(EditorController.showFind(_:)),"f"); item(edit,"Find Next",#selector(EditorController.findNext(_:)),"g")
        item(edit,"Find Previous",#selector(EditorController.findPrevious(_:)),"g",[.command,.shift]); item(edit,"Replace…",#selector(EditorController.showReplace(_:)),"f",[.command,.option])
        item(edit,"Go to Line…",#selector(EditorController.goToLine(_:)),"l"); item(edit,"Time and Date",#selector(EditorController.insertTimeDate(_:)),String(UnicodeScalar(NSF5FunctionKey)!),[])
        let format = menu("Format")
        item(format,"Word Wrap",#selector(EditorController.toggleWrap(_:))); item(format,"Font…",#selector(EditorController.chooseFont(_:)))
        let encoding = NSMenuItem(title: "Encoding",action: nil,keyEquivalent: ""); encoding.submenu = NSMenu(title: "Encoding"); format.addItem(encoding)
        for (i,value) in TextEncoding.allCases.enumerated() { let choice = NSMenuItem(title: value.rawValue,action: #selector(EditorController.setEncoding(_:)),keyEquivalent: ""); choice.tag = i; encoding.submenu!.addItem(choice) }
        let endings = NSMenuItem(title: "Normalize Line Endings",action: nil,keyEquivalent: ""); endings.submenu = NSMenu(title: "Normalize Line Endings"); format.addItem(endings)
        for (i,value) in LineEnding.allCases.enumerated() where value != .mixed { let choice = NSMenuItem(title: value.rawValue,action: #selector(EditorController.setEnding(_:)),keyEquivalent: ""); choice.tag = i; endings.submenu!.addItem(choice) }
        let view = menu("View"); item(view,"Zoom In",#selector(EditorController.zoomIn(_:)),"+")
        item(view,"Zoom Out",#selector(EditorController.zoomOut(_:)),"-"); item(view,"Reset Zoom",#selector(EditorController.resetZoom(_:)),"0"); view.addItem(.separator()); item(view,"Show Status Bar",#selector(EditorController.toggleStatus(_:)))
        let window = menu("Window"); NSApp.windowsMenu = window
        item(window,"Minimize",#selector(NSWindow.performMiniaturize(_:)),"m"); item(window,"Zoom",#selector(NSWindow.performZoom(_:))); window.addItem(.separator()); item(window,"Bring All to Front",#selector(NSApplication.arrangeInFront(_:)))
        let help = menu("Help"); NSApp.helpMenu = help; item(help,"PlainPad Help",#selector(showHelp(_:)))
    }
}
