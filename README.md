# Trace Your Lyf

A self-hosted digital wellbeing tracker that watches how you spend time across your **desktop** and **phone**, and surfaces it in a single dashboard — no cloud, no accounts, no telemetry.

Your data stays on your machine. The phone pairs with the desktop over your local network.

---

## What it does

- **Tracks the active window on your Mac** — app name, window title, browser URL, IDE project — every 2 seconds.
- **Tracks phone app usage on Android** via the system `UsageStats` API.
- **Shows one unified view** on the mobile app: today's screen time, per-app breakdown, hourly heatmap, weekly trend, streaks.
- **Classifies apps** as `productive`, `neutral`, or `distraction`, and you can change any of them.
- **Auto-pauses** when your Mac is locked.
- **Works with multiple devices** — pair several phones to one desktop, or connect one phone to several desktops and filter the view.

Everything is stored locally: SQLite on the desktop, SharedPreferences on the phone.

---

## Architecture

```
+----------------------------+         +----------------------------+
|  Desktop  (Python 3)       |         |  Mobile  (Flutter)         |
|                            |         |                            |
|  system tray  (pystray)    |         |  Dashboard / Apps /        |
|  window tracker  (AppleSc) |<--LAN-->|  Streaks / Profile         |
|  FastAPI  :8742            |  HTTP   |  UsageStats (Kotlin ch.)   |
|  SQLite ~/.traceyourlyf/   |         |  SharedPreferences         |
+----------------------------+         +----------------------------+
                                               pair code: 6 digits
                                               rotates every 2h
```

The desktop runs a local HTTP API on port `8742`. The phone pairs once using a 6-digit code shown in the tray menu, receives a long-lived token, then polls the API for usage data.

## Repo layout

```
trace_app/
├── desktop/         Python daemon (tray + tracker + API). See desktop/README.md
├── mobile/          Flutter app (Android).               See mobile/README.md
├── shared/          (reserved for future cross-platform schemas)
└── README.md        you are here
```

---

## Quick start

### 1. Start the desktop tracker (macOS)

```bash
cd trace_app
pip install -r desktop/requirements.txt
python3 -m desktop.main
```

On first launch macOS will prompt for **Accessibility** (AppleScript) and **Screen Recording** permissions — grant both.

A tray icon appears showing your local IP, port, and a 6-digit pairing code.

### 2. Install the mobile app

```bash
cd trace_app/mobile
flutter pub get
flutter build apk --release
flutter install   # to the currently connected device
```

### 3. Pair the phone

1. Open the app → **Pair with Desktop**.
2. Enter the IP, port, and the 6-digit code from the tray.
3. Grant the app **Usage Access** when prompted (Settings → Apps with usage access).

You're done. The dashboard will populate within a few seconds.

---

## Requirements

| Component | Requires                                                   |
|-----------|------------------------------------------------------------|
| Desktop   | macOS 11+, Python 3.9+, Accessibility & Screen Recording perms |
| Mobile    | Android 7+ (API 24), Flutter SDK 3.4+, `PACKAGE_USAGE_STATS`  |
| Network   | Phone and desktop on the same LAN                           |

Windows and Linux desktop trackers are not yet implemented. iOS is not planned (UsageStats equivalent requires MDM).

---

## Data & privacy

- All tracking data lives in `~/.traceyourlyf/tracker.db` on the desktop.
- The mobile app keeps only its list of paired desktops and user category overrides in SharedPreferences.
- The HTTP API binds to `0.0.0.0:8742` so the phone on your LAN can reach it. All non-public endpoints require the `X-Pair-Token` header.
- The pairing code rotates every 2 hours; paired tokens survive rotation.
- Nothing leaves your network. There is no telemetry and no account system.

---

## Roadmap

- Windows and Linux tracker modules
- QR-code pairing to skip manual IP/port entry
- Optional encrypted cloud sync (opt-in)
- Firefox URL support (currently not possible via AppleScript)
- Goals and notification reminders

---

## License

Personal project. No license file yet — treat as all-rights-reserved until one is added.
