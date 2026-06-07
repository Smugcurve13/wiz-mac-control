import AppIntents
import WidgetKit

/// The action behind the widget's power button.
///
/// Swift note: an `AppIntent` is a unit of work the system can run on your
/// behalf — from a widget tap, Shortcuts, or Spotlight. When a widget `Button`
/// is wired to an intent, tapping it runs `perform()` (here, in the widget
/// extension's process) and then refreshes the widget.
struct TogglePowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle WiZ Light"
    static var description = IntentDescription("Turns your WiZ bulb on or off.")

    func perform() async throws -> some IntentResult {
        let store = SharedStore()
        let ip = store.bulbIP
        guard !ip.isEmpty else { return .result() }   // nothing configured yet

        let current = store.lastState ?? .unknown
        let newOn = !current.isOn

        // Best-effort direct UDP from the widget. We swallow any network error
        // (`try?`) so the widget still flips optimistically; the menu bar app
        // reconciles the true state on its next refresh.
        try? await WizClient().setPower(newOn, host: ip)

        // Update the cached state so the widget redraws in the new state.
        var updated = current
        updated.isOn = newOn
        store.lastState = updated

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
