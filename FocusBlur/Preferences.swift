import Foundation
import Combine

/// Central settings store backed by UserDefaults.
/// Published properties drive live UI updates and overlay changes.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let blurRadius = "blurRadius"
        static let dimOpacity = "dimOpacity"
        static let shakeToToggle = "shakeToToggle"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var blurRadius: Double {
        didSet { UserDefaults.standard.set(blurRadius, forKey: Keys.blurRadius) }
    }

    /// Dim opacity as a fraction 0.0–1.0 (UI shows 0–100%)
    @Published var dimOpacity: Double {
        didSet { UserDefaults.standard.set(dimOpacity, forKey: Keys.dimOpacity) }
    }

    @Published var shakeToToggle: Bool {
        didSet { UserDefaults.standard.set(shakeToToggle, forKey: Keys.shakeToToggle) }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private init() {
        let defaults = UserDefaults.standard

        // Register defaults on first launch
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.blurRadius: 10.0,
            Keys.dimOpacity: 0.4,
            Keys.shakeToToggle: true,
            Keys.launchAtLogin: false,
        ])

        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        self.blurRadius = defaults.double(forKey: Keys.blurRadius)
        self.dimOpacity = defaults.double(forKey: Keys.dimOpacity)
        self.shakeToToggle = defaults.bool(forKey: Keys.shakeToToggle)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }
}
