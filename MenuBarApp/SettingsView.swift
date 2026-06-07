import SwiftUI

/// The preferences window (⌘,). Where the bulb IP is configured — no more
/// hardcoded BULB_IP.
struct SettingsView: View {

    @EnvironmentObject private var model: AppModel

    // `@State` is view-local, mutable storage. We edit a draft copy of the IP
    // and only commit it to the model on "Save".
    @State private var draftIP: String = ""
    @State private var testMessage: String = ""
    @State private var testing = false

    var body: some View {
        Form {
            Section("WiZ Bulb") {
                TextField("IP address", text: $draftIP, prompt: Text("e.g. 192.168.1.18"))
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") { model.saveIP(draftIP) }
                        .keyboardShortcut(.defaultAction)
                    Button("Test connection") { Task { await test() } }
                        .disabled(draftIP.trimmingCharacters(in: .whitespaces).isEmpty || testing)
                    if testing { ProgressView().controlSize(.small) }
                }

                if !testMessage.isEmpty {
                    Text(testMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                Text("The bulb listens on UDP port 38899. Make sure your Mac and the bulb are on the same Wi-Fi network.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .onAppear { draftIP = model.bulbIP }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        // Save first so refresh() uses the new IP, then probe the bulb.
        model.saveIP(draftIP)
        await model.refresh()
        testMessage = model.isReachable
            ? "✅ Connected — bulb is \(model.isOn ? "on" : "off")."
            : "❌ \(model.statusMessage)"
    }
}
