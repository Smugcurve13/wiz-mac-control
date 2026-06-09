# WiZ Control (native macOS)

A native macOS **menu bar app** that controls a
[WiZ](https://www.wizconnected.com/) smart bulb **directly over UDP** — no Flask
server, no cloud. It speaks the same JSON protocol your Python app used
(`setPilot` / `getPilot` on UDP port `38899`).

All controls live in one panel anchored to the menu bar icon:

- **Power** toggle and **Brightness** slider.
- **Colour mode:** a preset swatch grid + R/G/B sliders, rendered in-panel (so the
  system colour picker never opens a separate window, steals focus, and dismisses
  the panel).
- **White mode:** a colour-temperature slider (2200–6500 K) plus **Warm / Neutral /
  Cold** presets. A **Colour / White** switch selects the active mode — the two are
  mutually exclusive on the bulb, and the app infers the current mode from `getPilot`.
- Configurable bulb IP in Settings.

Built with SwiftUI and the Network framework.

---

## Requirements

- macOS 26 (Tahoe) and **Xcode 26** installed.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An Apple ID signed into Xcode (a **free personal team** is fine — see caveats below).

## Setup

```bash
# 1. Generate the Xcode project from project.yml
xcodegen generate

# 2. Open it
open WizControl.xcodeproj
```

In Xcode, select the `WizControl` target under **Signing & Capabilities** and pick
your team in the *Team* dropdown. To make signing survive future `xcodegen generate`
runs, paste your Team ID into `DEVELOPMENT_TEAM` in [`project.yml`](project.yml) instead.

Then **Run** (⌘R) the `WizControl` scheme. The app appears as a 💡 in the menu bar
(no Dock icon — it's an `LSUIElement` agent app).

> Building from the command line instead of the GUI? Point the toolchain at Xcode
> first: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
> (the GUI doesn't need this).

## Using it

1. Click the menu bar 💡 → **Settings…** (⌘,). Enter your bulb's IP (e.g.
   `192.168.1.18`) and click **Test connection**.
2. The first time the app sends a packet, macOS asks to **allow local network
   access** — click *Allow*. (This is required to reach the bulb on your LAN.)
3. Toggle power and drag brightness. Under **Colour**, tap a swatch or drag the
   R/G/B sliders; switch to **White** to set a colour temperature (slider or the
   Warm/Neutral/Cold presets). The bulb responds live.

## How it's organized

```
Shared/      WiZ networking + models
  WizClient.swift    UDP send/receive over NWConnection (async/await)
  WizCommand.swift   builds setPilot/getPilot JSON (state, dimming, r/g/b, temp)
  WizState.swift     Codable bulb state (+ mode/temp) + getPilot reply parsing
  SharedStore.swift  bulb IP + cached last state in a UserDefaults suite
MenuBarApp/  the menu bar app (non-sandboxed): AppModel + the SwiftUI panel
project.yml  the source of truth for the Xcode project (run xcodegen to regen)
```

The app polls `getPilot` when the panel opens, drives the UI from an `AppModel`
(`ObservableObject`), and caches `{bulbIP, lastState}` in a `UserDefaults` suite so
the panel looks right instantly at the next launch. Each control sends a `setPilot`
datagram over UDP — brightness/colour/temp commit on slider release to avoid
flooding the bulb mid-drag.

## WiZ protocol reference

UTF-8 JSON datagrams to `bulbIP:38899`:

| Action      | JSON |
|-------------|------|
| Power       | `{"method":"setPilot","params":{"state":true}}` |
| Brightness  | `{"method":"setPilot","params":{"dimming":50}}` *(10–100)* |
| Colour      | `{"method":"setPilot","params":{"r":255,"g":0,"b":0}}` *(0–255)* |
| White temp  | `{"method":"setPilot","params":{"temp":2700}}` *(2200–6500 K)* |
| Read state  | `{"method":"getPilot","params":{}}` |

Note: RGB colour and white `temp` are **mutually exclusive** — sending one clears
the other. The app tracks which mode is active and reflects it in the Colour/White
switch.

## Free Apple ID caveats

- **7-day expiry:** apps signed with a free personal team stop launching after ~7
  days. Just re-run from Xcode to refresh the signature.

## Troubleshooting

- **Bulb doesn't respond:** confirm the Mac and bulb are on the same Wi-Fi, the IP
  is correct, and you allowed local network access (System Settings ▸ Privacy &
  Security ▸ Local Network ▸ WiZ Control).
- **Signing errors:** select your team for the `WizControl` target in Xcode.
</content>
</invoke>
