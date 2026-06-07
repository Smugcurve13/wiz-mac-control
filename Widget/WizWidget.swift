import WidgetKit
import SwiftUI

// MARK: - Timeline data

/// One snapshot the widget can render. `TimelineEntry` requires a `date`.
struct WizEntry: TimelineEntry {
    let date: Date
    let state: WizState
    let hasIP: Bool
}

/// Supplies entries to WidgetKit. We read the cached state written by the app
/// (and by our own toggle intent) — no network call on the render path, so the
/// widget is always instant.
struct WizProvider: TimelineProvider {
    func placeholder(in context: Context) -> WizEntry {
        WizEntry(date: Date(), state: .unknown, hasIP: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (WizEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WizEntry>) -> Void) {
        let entry = makeEntry()
        // A lazy fallback refresh; interactive taps reload the timeline at once.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> WizEntry {
        let store = SharedStore()
        return WizEntry(date: Date(),
                        state: store.lastState ?? .unknown,
                        hasIP: !store.bulbIP.isEmpty)
    }
}

// MARK: - Widget definition

struct WizWidget: Widget {
    // Must match the kind used in `WidgetCenter.reloadTimelines(ofKind:)` calls.
    let kind = "WizControlWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WizProvider()) { entry in
            WizWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("WiZ Light")
        .description("See your bulb's state and toggle power.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct WizWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WizEntry

    var body: some View {
        if !entry.hasIP {
            noBulbView
        } else if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }

    /// Colour the bulb glyph with the bulb's own colour when it's on.
    private var bulbColor: Color {
        guard entry.state.isOn else { return .secondary }
        return Color(red: Double(entry.state.r) / 255,
                     green: Double(entry.state.g) / 255,
                     blue: Double(entry.state.b) / 255)
    }

    private var powerButton: some View {
        // A widget Button wired to an AppIntent = interactive widget.
        Button(intent: TogglePowerIntent()) {
            Image(systemName: entry.state.isOn ? "power.circle.fill" : "power.circle")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(entry.state.isOn ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
    }

    // Small: icon + status stacked, with the toggle.
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: entry.state.isOn ? "lightbulb.fill" : "lightbulb")
                .font(.system(size: 28))
                .foregroundStyle(bulbColor)
            Text("WiZ Light").font(.caption).foregroundStyle(.secondary)
            Text(entry.state.isOn ? "On · \(entry.state.dimming)%" : "Off")
                .font(.headline)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                powerButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // Medium: details on the left, big toggle on the right.
    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: entry.state.isOn ? "lightbulb.fill" : "lightbulb")
                        .foregroundStyle(bulbColor)
                    Text("WiZ Light").font(.headline)
                }
                Text(entry.state.isOn ? "On" : "Off")
                    .font(.title2).bold()
                if entry.state.isOn {
                    Label("\(entry.state.dimming)%", systemImage: "sun.max")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Circle().fill(bulbColor).frame(width: 12, height: 12)
                        Text("Colour").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            Spacer()
            powerButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var noBulbView: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2).foregroundStyle(.orange)
            Text("Open WiZ Control and set your bulb's IP.")
                .font(.caption).multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
