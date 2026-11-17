import AppKit
import TopChromeCore

final class Preferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["heightFraction": DrawerGeometry.defaultFraction])
    }
    var heightFraction: Double {
        get { DrawerGeometry.savedFraction(defaults.double(forKey: "heightFraction")) }
        set { defaults.set(DrawerGeometry.savedFraction(newValue), forKey: "heightFraction") }
    }
    var ownerName: String {
        if let stored = defaults.string(forKey: "windowOwner"), !stored.isEmpty { return stored }
        let name = "TopChrome · " + UUID().uuidString.prefix(8)
        defaults.set(name, forKey: "windowOwner")
        return name
    }
    var keyBinding: KeyBinding {
        get {
            guard let data = defaults.data(forKey: "showHideShortcut"),
                  let binding = try? JSONDecoder().decode(KeyBinding.self, from: data), binding.isValid else { return .defaultBinding }
            return binding
        }
        set {
            guard newValue.isValid, let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: "showHideShortcut")
        }
    }
    var hidden: Bool {
        get { defaults.bool(forKey: "drawerHidden") }
        set { defaults.set(newValue, forKey: "drawerHidden") }
    }
    var lastVisibleBounds: [Int]? {
        get { defaults.array(forKey: "lastVisibleBounds") as? [Int] }
        set { defaults.set(newValue, forKey: "lastVisibleBounds") }
    }
}

enum Palette {
    static let background = NSColor(srgbRed: 0.065, green: 0.077, blue: 0.10, alpha: 1)
    static let accent = NSColor(srgbRed: 0.49, green: 0.72, blue: 1, alpha: 1)
    static let foreground = NSColor(srgbRed: 0.9, green: 0.93, blue: 0.98, alpha: 1)
}
