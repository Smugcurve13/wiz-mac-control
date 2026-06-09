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

            // ── Colour / White ──────────────────────────────────────────────
            // RGB colour and white temperature are mutually exclusive on the bulb,
            // so a segmented switch picks which one is live. Changing it re-commands
            // the bulb (see AppModel.setMode). Both control sets live *inside* this
            // panel — no system colour-picker window to steal focus and dismiss us.
            VStack(alignment: .leading, spacing: 10) {
                Picker("Mode", selection: Binding(
                    get: { model.mode },
                    set: { newMode in
                        model.mode = newMode               // optimistic: switch UI now
                        Task { await model.setMode(newMode) }
                    }
                )) {
                    Text("Colour").tag(WizMode.color)
                    Text("White").tag(WizMode.white)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if model.mode == .color {
                    colorControls
                } else {
                    whiteControls
                }
            }
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
        .frame(width: 280)
        // Refresh live state whenever the menu is opened.
        .task { await model.refresh() }
    }

    // ── Colour-mode controls ────────────────────────────────────────────────

    /// A preset colour, stored as the raw 0...255 components the bulb expects.
    private struct Swatch: Hashable { let r, g, b: Double }

    private static let swatches: [Swatch] = [
        Swatch(r: 255, g: 59,  b: 48),    // red
        Swatch(r: 255, g: 149, b: 0),     // orange
        Swatch(r: 255, g: 214, b: 10),    // yellow
        Swatch(r: 124, g: 205, b: 52),    // lime
        Swatch(r: 52,  g: 199, b: 89),    // green
        Swatch(r: 48,  g: 176, b: 199),   // teal
        Swatch(r: 50,  g: 210, b: 230),   // cyan
        Swatch(r: 0,   g: 122, b: 255),   // blue
        Swatch(r: 88,  g: 86,  b: 214),   // indigo
        Swatch(r: 175, g: 82,  b: 222),   // purple
        Swatch(r: 255, g: 45,  b: 85),    // pink
        Swatch(r: 255, g: 255, b: 255),   // white
    ]

    /// Preset swatches plus R/G/B sliders — entirely in-panel.
    @ViewBuilder
    private var colorControls: some View {
        // `LazyVGrid` lays children out in flexible columns (lazy = it builds
        // cells on demand). 6 columns × 12 swatches = two tidy rows.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                  spacing: 8) {
            ForEach(Self.swatches, id: \.self) { swatch in
                Button {
                    model.red = swatch.r
                    model.green = swatch.g
                    model.blue = swatch.b
                    Task { await model.applyColor() }
                } label: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: swatch.r / 255, green: swatch.g / 255, blue: swatch.b / 255))
                        .frame(height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.primary.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }

        rgbSlider("R", value: $model.red, tint: .red)
        rgbSlider("G", value: $model.green, tint: .green)
        rgbSlider("B", value: $model.blue, tint: .blue)
    }

    /// One labelled 0...255 component slider that sends on release only (like the
    /// brightness slider) so we don't flood the bulb with packets mid-drag.
    private func rgbSlider(_ label: String, value: Binding<Double>, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 12)
            Slider(value: value, in: 0...255, step: 1) { editing in
                if !editing { Task { await model.applyColor() } }
            }
            .tint(tint)
            Text("\(Int(value.wrappedValue))")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // ── White-mode controls ─────────────────────────────────────────────────

    /// White colour-temperature slider (warm ↔ cold) plus quick presets.
    @ViewBuilder
    private var whiteControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Temperature")
                Spacer()
                Text("\(Int(model.temperature))K").foregroundStyle(.secondary)
            }
            Slider(value: $model.temperature, in: 2200...6500, step: 50) { editing in
                if !editing { Task { await model.applyTemperature() } }
            }

            HStack(spacing: 8) {
                tempPreset("Warm", kelvin: 2700)
                tempPreset("Neutral", kelvin: 4000)
                tempPreset("Cold", kelvin: 6500)
            }
        }
    }

    private func tempPreset(_ title: String, kelvin: Int) -> some View {
        Button(title) {
            model.temperature = Double(kelvin)
            Task { await model.applyTemperature() }
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
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
