import SwiftUI
import AppKit
import WidgetKit

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
    @Published var color: Color
    @Published var statusMessage: String = ""
    @Published var isReachable: Bool = false
    @Published var isBusy: Bool = false

    private let client = WizClient()
    private let store = SharedStore()

    init() {
        // Seed the UI from whatever we last cached, so it looks right instantly.
        let cached = store.lastState ?? .unknown
        bulbIP = store.bulbIP
        isOn = cached.isOn
        brightness = Double(cached.dimming)
        color = Color(red: Double(cached.r) / 255,
                      green: Double(cached.g) / 255,
                      blue: Double(cached.b) / 255)

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

    func applyColor() async {
        let (r, g, b) = Self.rgb(from: color)
        do {
            try await client.setColor(r: r, g: g, b: b, host: bulbIP)
            succeed()
        } catch { fail(error) }
    }

    /// Save a new bulb IP from Settings and let the widget pick it up.
    func saveIP(_ ip: String) {
        bulbIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        store.bulbIP = bulbIP
        WidgetCenter.shared.reloadAllTimelines()
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

    /// Mirror the current UI state into shared storage and refresh the widget.
    private func persist() {
        let (r, g, b) = Self.rgb(from: color)
        store.lastState = WizState(isOn: isOn, dimming: Int(brightness), r: r, g: g, b: b)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func apply(_ state: WizState) {
        isOn = state.isOn
        brightness = Double(state.dimming)
        color = Color(red: Double(state.r) / 255,
                      green: Double(state.g) / 255,
                      blue: Double(state.b) / 255)
        store.lastState = state
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// SwiftUI `Color` → 0...255 RGB the bulb understands. We force sRGB so the
    /// numbers are predictable regardless of the display's colour space.
    static func rgb(from color: Color) -> (Int, Int, Int) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return (Int((ns.redComponent * 255).rounded()),
                Int((ns.greenComponent * 255).rounded()),
                Int((ns.blueComponent * 255).rounded()))
    }
}
