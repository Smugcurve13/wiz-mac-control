import Foundation

/// The app's small persistence layer: the configurable bulb IP and a cached
/// snapshot of the last known bulb state.
///
/// It uses a named `UserDefaults` "suite" — a plist that lives at
/// `~/Library/Preferences/WizControlShared.plist`. (The suite name is kept from
/// when a widget extension also read this file; leaving it unchanged means your
/// previously-saved bulb IP still loads. Plain `.standard` defaults would work
/// equally well now that there's a single process.)
struct SharedStore {

    /// The UserDefaults suite backing this store. Kept stable so existing saved
    /// values (e.g. your bulb IP) survive across launches.
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
