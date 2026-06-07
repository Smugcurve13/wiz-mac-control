import SwiftUI

/// The dropdown shown when you click the menu bar icon: power, brightness,
/// colour, status, and links to Settings / Refresh / Quit.
struct MenuContentView: View {

    // Receives the shared model injected by `WizControlApp`.
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Header ──────────────────────────────────────────────────────
            HStack {
                Image(systemName: model.isOn ? "lightbulb.fill" : "lightbulb")
                    .foregroundStyle(model.isOn ? .yellow : .secondary)
                Text("WiZ Light").font(.headline)
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
            }

            Divider()

            // ── Power ───────────────────────────────────────────────────────
            // The toggle's value comes from the model; flipping it sends a
            // command. We build a custom Binding because the "set" side needs to
            // kick off an async network call.
            Toggle("Power", isOn: Binding(
                get: { model.isOn },
                set: { newValue in Task { await model.setPower(newValue) } }
            ))
            .toggleStyle(.switch)
            .disabled(model.bulbIP.isEmpty)

            // ── Brightness ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Brightness")
                    Spacer()
                    Text("\(Int(model.brightness))%").foregroundStyle(.secondary)
                }
                // `$model.brightness` is a two-way Binding to the published value.
                // We only send to the bulb when the drag *ends* (editing == false)
                // to avoid flooding it with packets mid-drag.
                Slider(value: $model.brightness, in: 10...100, step: 1) { editing in
                    if !editing { Task { await model.applyBrightness() } }
                }
                .disabled(model.bulbIP.isEmpty || !model.isOn)
            }

            // ── Colour ──────────────────────────────────────────────────────
            ColorPicker("Colour", selection: Binding(
                get: { model.color },
                set: { newColor in
                    model.color = newColor
                    Task { await model.applyColor() }
                }
            ))
            .disabled(model.bulbIP.isEmpty || !model.isOn)

            // ── Status line ─────────────────────────────────────────────────
            statusLine

            Divider()

            // ── Footer actions ──────────────────────────────────────────────
            HStack {
                SettingsLink { Text("Settings…") }
                Spacer()
                Button("Refresh") { Task { await model.refresh() } }
            }
            Button("Quit WiZ Control") { NSApplication.shared.terminate(nil) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(width: 260)
        // Refresh live state whenever the menu is opened.
        .task { await model.refresh() }
    }

    @ViewBuilder
    private var statusLine: some View {
        if model.bulbIP.isEmpty {
            Label("No bulb configured", systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.orange)
        } else if !model.statusMessage.isEmpty {
            Label(model.statusMessage, systemImage: "wifi.exclamationmark")
                .font(.caption).foregroundStyle(.red)
        } else {
            Label("Connected · \(model.bulbIP)", systemImage: "wifi")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
