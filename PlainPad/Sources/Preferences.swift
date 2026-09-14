import AppKit

final class Preferences {
    static let shared = Preferences()
    static let changed = Notification.Name("PlainPadDisplayChanged")
    private let defaults = UserDefaults.standard
    var wrap: Bool { get { defaults.object(forKey: "wrap") as? Bool ?? true } set { defaults.set(newValue, forKey: "wrap"); notify() } }
    var status: Bool { get { defaults.object(forKey: "status") as? Bool ?? true } set { defaults.set(newValue, forKey: "status"); notify() } }
    var font: NSFont {
        get { NSFont(name: defaults.string(forKey: "font") ?? "Menlo-Regular", size: defaults.object(forKey: "fontSize") as? Double ?? 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular) }
        set { defaults.set(newValue.fontName, forKey: "font"); defaults.set(newValue.pointSize, forKey: "fontSize"); notify() }
    }
    private func notify() { NotificationCenter.default.post(name: Self.changed, object: nil) }
}
