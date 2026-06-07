import WidgetKit
import SwiftUI

/// The widget extension's entry point. A `WidgetBundle` can hold multiple
/// widgets; we ship one. `@main` here is separate from the app's `@main` — each
/// target has its own entry point.
@main
struct WizControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        WizWidget()
    }
}
