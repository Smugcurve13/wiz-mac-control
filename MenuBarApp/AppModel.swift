import SwiftUI

/// The single source of truth for the menu bar app's UI.
///
/// Swift note: an `ObservableObject` is a reference type (a `class`) whose
/// `@Published` properties automatically notify any SwiftUI view watching them —
/// this is SwiftUI's reactivity, similar in spirit to a Vue/React store. The
/// `@MainActor` annotation guarantees every property and method runs on the main
/// thread, which is required for UI updates (so we never touch `@Published` from
/// a background thread by accident).
@MainActor
final class AppModel: ObservableObject {

    @Published var bulbIP: String
    @Published var isOn: Bool
    @Published var brightness: Double        // 10...100
    @Published var red: Double               // 0...255  ┐ colour-mode RGB, kept as
    @Published var green: Double             // 0...255  │ the source of truth so the
    @Published var blue: Double              // 0...255  ┘ sliders/swatches bind directly
    @Published var temperature: Double       // 2200...6500 K (white mode)
    @Published var mode: WizMode             // .color or .white — which control is live
    @Published var statusMessage: String = ""
    @Published var isReachable: Bool = false
    @Published var isBusy: Bool = false

    /// The current colour as a SwiftUI `Color`, derived from r/g/b. A computed
    /// property (no stored backing), so it always reflects the three published
    /// values — handy for swatch previews and tinting.
    var color: Color { Color(red: red / 255, green: green / 255, blue: blue / 255) }

    private let client = WizClient()
    private let store = SharedStore()

    init() {
        // Seed the UI from whatever we last cached, so it looks right instantly.
        let cached = store.lastState ?? .unknown
        bulbIP = store.bulbIP
        isOn = cached.isOn
        brightness = Double(cached.dimming)
        red = Double(cached.r)
        green = Double(cached.g)
        blue = Double(cached.b)
        temperature = Double(cached.temp)
        mode = cached.mode

        // Fetch live state at launch. This first UDP packet is also what makes
        // macOS show the "allow local network access?" prompt.
        Task { await refresh() }
    }

    // MARK: - Actions called from the UI

    /// Pull the bulb's real current state and update the UI + cache.
    func refresh() async {
        guard !bulbIP.isEmpty else {
            statusMessage = "Set a bulb IP in Settings (⌘,)."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let state = try await client.getState(host: bulbIP)
            apply(state)
            isReachable = true
            statusMessage = ""
        } catch {
            isReachable = false
            statusMessage = error.localizedDescription
        }
    }

    func setPower(_ on: Bool) async {
        do {
            try await client.setPower(on, host: bulbIP)
            isOn = on
            succeed()
        } catch { fail(error) }
    }

    /// Call when the brightness slider is released (not on every drag tick).
    func applyBrightness() async {
        do {
            try await client.setBrightness(Int(brightness), host: bulbIP)
            succeed()
        } catch { fail(error) }
    }

    /// Send the current r/g/b and put the bulb into colour mode (clears white temp).
    func applyColor() async {
        do {
            try await client.setColor(r: Int(red), g: Int(green), b: Int(blue), host: bulbIP)
            mode = .color
            succeed()
        } catch { fail(error) }
    }

    /// Send the current white colour temperature and put the bulb into white mode
    /// (clears r/g/b). The `temp` UDP command already existed in WizCommand.
    func applyTemperature() async {
        do {
            try await client.setTemperature(Int(temperature), host: bulbIP)
            mode = .white
            succeed()
        } catch { fail(error) }
    }

    /// Called by the Colour/White segmented control. Flipping the segment doesn't
    /// just swap the UI — it re-commands the bulb into that mode using whichever
    /// colour or temperature is currently selected.
    func setMode(_ newMode: WizMode) async {
        switch newMode {
        case .color: await applyColor()
        case .white: await applyTemperature()
        }
    }

    /// Save a new bulb IP from Settings and re-test the connection.
    func saveIP(_ ip: String) {
        bulbIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        store.bulbIP = bulbIP
        Task { await refresh() }
    }

    // MARK: - Helpers

    private func succeed() {
        isReachable = true
        statusMessage = ""
        persist()
    }

    private func fail(_ error: Error) {
        isReachable = false
        statusMessage = error.localizedDescription
    }

    /// Mirror the current UI state into local storage so it's cached at next launch.
    private func persist() {
        store.lastState = WizState(isOn: isOn, dimming: Int(brightness),
                                   r: Int(red), g: Int(green), b: Int(blue),
                                   temp: Int(temperature), mode: mode)
    }

    private func apply(_ state: WizState) {
        isOn = state.isOn
        brightness = Double(state.dimming)
        red = Double(state.r)
        green = Double(state.g)
        blue = Double(state.b)
        temperature = Double(state.temp)
        mode = state.mode
        store.lastState = state
    }
}
