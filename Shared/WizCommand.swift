import Foundation

/// Builds the JSON datagrams the WiZ bulb understands. These match exactly what
/// your Flask app sent, e.g. `{"method":"setPilot","params":{"state":true}}`.
///
/// Swift note: an `enum` with only `static` functions is a common Swift idiom
/// for a namespace of related helpers (it can't be instantiated). Think of it
/// as a module of free functions.
enum WizCommand {

    /// Encode a `{"method": ..., "params": ...}` object into UTF-8 JSON bytes.
    private static func encode(method: String, params: [String: Any]) -> Data {
        let object: [String: Any] = ["method": method, "params": params]
        // `try!` force-unwraps: we built this dictionary ourselves from valid
        // JSON types, so serialization cannot fail here.
        return try! JSONSerialization.data(withJSONObject: object)
    }

    /// `{"method":"setPilot","params":{"state":true/false}}`
    static func setPower(_ on: Bool) -> Data {
        encode(method: "setPilot", params: ["state": on])
    }

    /// `{"method":"setPilot","params":{"dimming":NN}}` — WiZ accepts 10...100.
    static func setBrightness(_ percent: Int) -> Data {
        let clamped = min(100, max(10, percent))
        return encode(method: "setPilot", params: ["dimming": clamped])
    }

    /// `{"method":"setPilot","params":{"r":R,"g":G,"b":B}}` — each 0...255.
    /// Note: setting RGB puts the bulb in colour mode (clears white `temp`).
    static func setColor(r: Int, g: Int, b: Int) -> Data {
        encode(method: "setPilot", params: [
            "r": clampByte(r), "g": clampByte(g), "b": clampByte(b),
        ])
    }

    /// `{"method":"setPilot","params":{"temp":K}}` — white colour temperature.
    static func setTemperature(kelvin: Int) -> Data {
        encode(method: "setPilot", params: ["temp": kelvin])
    }

    /// `{"method":"getPilot","params":{}}` — ask the bulb for its current state.
    static let getPilot: Data = {
        encode(method: "getPilot", params: [:])
    }()

    private static func clampByte(_ v: Int) -> Int { min(255, max(0, v)) }
}
