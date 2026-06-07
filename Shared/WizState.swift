import Foundation

/// The bulb's current state, as we care about it.
///
/// Swift note: a `struct` is a value type (copied on assignment), like a Python
/// `@dataclass` but copied rather than referenced. `Codable` means Swift can
/// automatically convert it to/from JSON — the rough equivalent of Python's
/// `json.dumps` / `json.loads`, but type-checked at compile time.
struct WizState: Codable, Equatable {
    var isOn: Bool
    var dimming: Int        // 10...100 (brightness %)
    var r: Int
    var g: Int
    var b: Int

    /// A neutral default to show before we've heard from the bulb.
    static let unknown = WizState(isOn: false, dimming: 100, r: 255, g: 255, b: 255)
}

/// The shape of a `getPilot` reply from the bulb, e.g.:
/// `{"method":"getPilot","env":"pro","result":{"state":true,"dimming":100,"r":255,...}}`
///
/// Every field is optional because WiZ only includes the ones relevant to the
/// bulb's current mode (e.g. it sends `temp` in white mode, `r/g/b` in colour
/// mode). Decoding ignores any keys we don't declare here.
struct GetPilotResponse: Codable {
    struct Result: Codable {
        var state: Bool?
        var dimming: Int?
        var r: Int?
        var g: Int?
        var b: Int?
        var temp: Int?
        var sceneId: Int?
    }
    var result: Result?

    /// Convert a raw reply into our tidy `WizState`, filling gaps with sensible
    /// defaults (a bulb in white mode reports no r/g/b, so we fall back to white).
    func toState() -> WizState {
        let res = result
        return WizState(
            isOn: res?.state ?? false,
            dimming: res?.dimming ?? 100,
            r: res?.r ?? 255,
            g: res?.g ?? 255,
            b: res?.b ?? 255
        )
    }
}
