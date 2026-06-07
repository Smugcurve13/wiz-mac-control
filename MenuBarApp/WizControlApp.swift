import SwiftUI

/// The app entry point.
///
/// Swift note: `@main` marks the program's starting point (like Python's
/// `if __name__ == "__main__":`). A SwiftUI `App` describes one or more
/// `Scene`s. We use two:
///   • `MenuBarExtra` — the menu bar item and its dropdown (SwiftUI's modern
///     wrapper around `NSStatusItem`).
///   • `Settings` — the standard preferences window (opened with ⌘, or the
///     "Settings…" button in the menu).
@main
struct WizControlApp: App {

    // `@StateObject` creates and owns the model for the app's lifetime.
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(model)
        } label: {
            // The menu bar icon reflects on/off at a glance.
            Image(systemName: model.isOn ? "lightbulb.fill" : "lightbulb")
        }
        // `.window` style allows rich controls (sliders, colour picker) in the
        // dropdown. The default `.menu` style only supports menu items/buttons.
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
