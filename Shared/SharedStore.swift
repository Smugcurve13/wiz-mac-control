import Foundation

/// The bridge between the menu bar app and the widget extension.
///
/// They are two separate processes that can't see each other's memory, so they
/// share data through a named `UserDefaults` "suite" — a small plist that, for
/// the (non-sandboxed) app, lives at `~/Library/Preferences/WizControlShared.plist`.
/// The sandboxed widget reaches that same file via the
/// `com.apple.security.temporary-exception.shared-preference.read-write`
/// entitlement (see project.yml). Same API on both sides.
///
/// Upgrade path: if you ever get a paid Apple Developer account, change
/// `suiteName` to an App Group id (e.g. "group.com.smugcurve13.wizcontrol") and
/// add the App Group capability — the rest of this code stays identical.
struct SharedStore {

    /// Must be the SAME string in the app and the widget (and must match the
    /// value in the widget's shared-preference entitlement).
    static let suiteName = "WizControlShared"

    private let defaults: UserDefaults

    init() {
        // Falls back to `.standard` only if the suite somehow can't be opened,
        // so the app never crashes here.
        defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
    }

    private enum Keys {
        static let bulbIP = "bulbIP"
        static let lastState = "lastState"
    }

    /// The configurable bulb IP (replaces the old hardcoded BULB_IP).
    /// `nonmutating set` lets us write even though `defaults` is a `let` — we're
    /// mutating the UserDefaults object, not the struct itself.
    var bulbIP: String {
        get { defaults.string(forKey: Keys.bulbIP) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Keys.bulbIP) }
    }

    /// The last known bulb state, cached so the widget can render instantly
    /// without doing its own network round-trip on every refresh.
    var lastState: WizState? {
        get {
            guard let data = defaults.data(forKey: Keys.lastState) else { return nil }
            return try? JSONDecoder().decode(WizState.self, from: data)
        }
        nonmutating set {
            guard let value = newValue,
                  let data = try? JSONEncoder().encode(value) else { return }
            defaults.set(data, forKey: Keys.lastState)
        }
    }
}
