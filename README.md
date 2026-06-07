# WiZ Control (native macOS)

A native macOS **menu bar app** + **interactive WidgetKit widget** that controls a
[WiZ](https://www.wizconnected.com/) smart bulb **directly over UDP** — no Flask
server, no cloud. It speaks the same JSON protocol your Python app used
(`setPilot` / `getPilot` on UDP port `38899`).

- **Menu bar app:** power toggle, brightness slider, colour picker, configurable bulb IP.
- **Widget (small + medium):** shows the bulb state and an interactive power button
  (App Intents).

Built with SwiftUI, WidgetKit, App Intents, and the Network framework.

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

In Xcode, for **both** targets (`WizControl` and `WizControlWidget`) under
**Signing & Capabilities**, pick your team in the *Team* dropdown. To make signing
survive future `xcodegen generate` runs, paste your Team ID into `DEVELOPMENT_TEAM`
in [`project.yml`](project.yml) instead.

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
3. Toggle power, drag brightness, pick a colour — the bulb responds live.
4. Add the widget: right-click the desktop / open Notification Center → **Edit
   Widgets** → find **WiZ Light** → add the small or medium size.

## How it's organized

```
Shared/      WiZ networking + models, compiled into BOTH targets
  WizClient.swift    UDP send/receive over NWConnection (async/await)
  WizCommand.swift   builds setPilot/getPilot JSON
  WizState.swift     Codable bulb state + getPilot reply parsing
  SharedStore.swift  app↔widget bridge (shared UserDefaults suite)
MenuBarApp/  the menu bar app (non-sandboxed)
Widget/      the WidgetKit extension (sandboxed) + TogglePowerIntent
project.yml  the source of truth for the Xcode project (run xcodegen to regen)
```

The menu bar app is the source of truth: it polls `getPilot`, drives the UI, writes
`{bulbIP, lastState}` to a shared `UserDefaults` suite, and reloads the widget. The
widget renders that cached state and, on a tap, sends `setPilot` over UDP itself.

## WiZ protocol reference

UTF-8 JSON datagrams to `bulbIP:38899`:

| Action      | JSON |
|-------------|------|
| Power       | `{"method":"setPilot","params":{"state":true}}` |
| Brightness  | `{"method":"setPilot","params":{"dimming":50}}` *(10–100)* |
| Colour      | `{"method":"setPilot","params":{"r":255,"g":0,"b":0}}` *(0–255)* |
| Read state  | `{"method":"getPilot","params":{}}` |

Note: RGB colour and white `temp` are mutually exclusive on WiZ bulbs.

## Free Apple ID caveats

- **7-day expiry:** apps signed with a free personal team stop launching after ~7
  days. Just re-run from Xcode to refresh the signature.
- **No App Groups:** App Groups need a paid account, so the app↔widget bridge uses
  a shared-preference *temporary-exception* entitlement instead (see
  `Widget/Widget.entitlements`). If you later go paid, switch `SharedStore.suiteName`
  to a `group.*` id, add the App Group capability, and the code is unchanged.
- **Widget networking:** sending LAN UDP from a sandboxed widget extension can be
  blocked by local-network privacy (the grant is per-process). The menu bar app's
  control is rock-solid; the widget toggle is best-effort. If it misbehaves, the
  fallback is to have the widget post a Darwin notification the running app handles
  (not wired up yet).

## Troubleshooting

- **Bulb doesn't respond:** confirm the Mac and bulb are on the same Wi-Fi, the IP
  is correct, and you allowed local network access (System Settings ▸ Privacy &
  Security ▸ Local Network ▸ WiZ Control).
- **Widget shows "set your bulb's IP":** open the app and save an IP first; the
  widget reads it from shared storage.
- **Signing errors:** select your team for both targets in Xcode.
