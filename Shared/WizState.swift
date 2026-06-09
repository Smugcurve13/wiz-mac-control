import Foundation

/// The bulb's current state, as we care about it.
///
/// Swift note: a `struct` is a value type (copied on assignment), like a Python
/// `@dataclass` but copied rather than referenced. `Codable` means Swift can
/// automatically convert it to/from JSON — the rough equivalent of Python's
/// `json.dumps` / `json.loads`, but type-checked at compile time.
/// Which lighting mode the bulb is in. RGB colour and white `temp` are mutually
/// exclusive on WiZ bulbs — setting one clears the other — so we track which is
/// active and show the matching control.
///
/// Swift note: an `enum` with a `String` raw value is like a Python `enum.Enum`
/// whose members serialise to strings. `Codable` conformance is free here, so it
/// JSON-encodes as `"color"` / `"white"`.
enum WizMode: String, Codable {
    case color
    case white
}

struct WizState: Codable, Equatable {
    var isOn: Bool
    var dimming: Int        // 10...100 (brightness %)
    var r: Int
    var g: Int
    var b: Int
    var temp: Int           // white colour temperature in Kelvin (2200...6500)
    var mode: WizMode       // .color (r/g/b active) or .white (temp active)

    /// A neutral default to show before we've heard from the bulb.
    static let unknown = WizState(isOn: false, dimming: 100, r: 255, g: 255, b: 255,
                                  temp: 2700, mode: .color)
}

extension WizState {
    /// Lenient JSON decoding so an older cached `lastState` (written before `temp`
    /// and `mode` existed) still loads instead of being silently discarded. Each
    /// field falls back to a default when its key is missing — the rough
    /// equivalent of Python's `dict.get(key, default)`.
    ///
    /// Swift note: declaring this `init(from:)` in an *extension* (rather than the
    /// main `struct` body) preserves the compiler-synthesised memberwise
    /// initialiser `WizState(isOn:dimming:r:g:b:temp:mode:)`, so the call sites
    /// above keep compiling. `CodingKeys` is still synthesised automatically.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isOn    = try c.decodeIfPresent(Bool.self,    forKey: .isOn)    ?? false
        dimming = try c.decodeIfPresent(Int.self,     forKey: .dimming) ?? 100
        r       = try c.decodeIfPresent(Int.self,     forKey: .r)       ?? 255
        g       = try c.decodeIfPresent(Int.self,     forKey: .g)       ?? 255
        b       = try c.decodeIfPresent(Int.self,     forKey: .b)       ?? 255
        temp    = try c.decodeIfPresent(Int.self,     forKey: .temp)    ?? 2700
        mode    = try c.decodeIfPresent(WizMode.self, forKey: .mode)    ?? .color
    }
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
        // WiZ reports `temp` only in white mode and `r/g/b` only in colour mode,
        // so the presence of `temp` in the reply tells us which mode the bulb is in.
        let isWhite = res?.temp != nil
        return WizState(
            isOn: res?.state ?? false,
            dimming: res?.dimming ?? 100,
            r: res?.r ?? 255,
            g: res?.g ?? 255,
            b: res?.b ?? 255,
            temp: res?.temp ?? 2700,
            mode: isWhite ? .white : .color
        )
    }
}
