# Trace Your Lyf — Mobile

Flutter app (Android-first) that pairs with one or more Trace Your Lyf desktops over the local network and shows unified screen-time data — phone and computer in one dashboard.

---

## Features

- **4 tabs:** Dashboard, Apps (Applications + Websites), Streaks, Profile.
- **Phone usage via Android `UsageStats`** through a Kotlin method channel.
- **Desktop usage via HTTP** against the paired desktop's API on port 8742.
- **Multi-device** — pair multiple desktops, filter by a specific device or view `All Devices` / `This Phone`.
- **Categories** — tag any app as `productive`, `neutral`, or `distraction`. Changes sync to the desktop too.
- **Websites view** — browsed domains (from desktop URL tracking), with favicons via Google's favicon API.
- **Streaks** — daily goal tracking.
- **Auto-refresh** every 30 s while the app is in the foreground; pauses on background, resumes on foreground.
- **Offline-tolerant** — all per-app category preferences live in SharedPreferences.

---

## Design

- **Dark theme**, accent color `#E8891D` (orange).
- **Gilroy** font family, shipped in `assets/fonts/`.
- State managed with **Provider**; charts drawn with **fl_chart**.

---

## Requirements

- Flutter SDK 3.4+
- Android 7+ (API 24, minSdk)
- A Trace Your Lyf desktop running on the same LAN
- `PACKAGE_USAGE_STATS` permission (user-granted via system Settings)

iOS is not supported — the equivalent of UsageStats requires MDM/Screen Time APIs that aren't available to regular App Store apps.

---

## Quick start

```bash
cd trace_app/mobile
flutter pub get
flutter build apk --release
flutter install -d <device-id>   # or just flutter install
```

> **Use `--release`** rather than `flutter run` for day-to-day testing. Debug builds are large and the device may not have room.

To list devices: `flutter devices`.

---

## First-run flow

1. **Splash screen** → checks SharedPreferences for paired desktops.
2. If none: **Pair with Desktop** screen.
   - Enter the **IP** and **port** (default `8742`) shown in the desktop tray icon.
   - Enter the **6-digit pairing code** from the tray menu.
   - App calls `POST /pair`, stores the returned token.
3. App asks for **Usage Access** permission. Tap through to Settings → enable Trace Your Lyf.
4. Dashboard loads.

To pair additional desktops later: **Profile → Paired Devices → Add Desktop**.

---

## Project layout

```
mobile/
├── lib/
│   ├── main.dart               app bootstrap, theme, providers
│   ├── config.dart             constants (port, polling interval, brand color)
│   ├── theme/                  ThemeData, text styles
│   ├── models/
│   │   ├── usage_record.dart
│   │   ├── daily_summary.dart
│   │   ├── device.dart
│   │   └── app_category.dart
│   ├── providers/
│   │   ├── pairing_provider.dart    paired desktops, active filter
│   │   └── usage_provider.dart      combined phone + desktop usage, refresh loop
│   ├── services/
│   │   ├── desktop_api_service.dart HTTP client (10 s timeout, token header)
│   │   ├── phone_usage_service.dart method channel → Kotlin UsageStats
│   │   └── category_service.dart    SharedPreferences + desktop sync
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── auth/                    (placeholder for future real auth)
│   │   ├── pairing/                 pair entry, device list
│   │   ├── home/                    bottom-nav scaffold
│   │   ├── dashboard/               today summary, hourly chart, weekly trend
│   │   ├── apps/                    applications + websites sub-tabs
│   │   ├── streaks/                 goal tracking
│   │   └── profile/                 paired devices, app categories, settings
│   └── widgets/
│       └── app_icon_widget.dart     known-app icon lookup + letter fallback
├── android/
│   └── app/src/main/kotlin/com/traceyourlyf/trace_app/MainActivity.kt
│       MethodChannel handler for UsageStatsManager + permission check
├── assets/
│   └── fonts/Gilroy-*.ttf
└── pubspec.yaml
```

---

## Android integration

Phone usage is read in Kotlin (`MainActivity.kt`) via `UsageStatsManager.queryAndAggregateUsageStats(...)` and surfaced to Dart through a single `MethodChannel`.

Two things to know:

1. **Updates happen on app switch, not in real time.** That's a UsageStats limitation, not a bug. Switch apps (or lock/unlock) and the numbers advance.
2. **Permission is `PACKAGE_USAGE_STATS`**, which is a protected permission — the app cannot request it via the normal permission dialog. It opens `Settings.ACTION_USAGE_ACCESS_SETTINGS` and the user toggles it manually.

The app checks for the permission on every foreground and prompts again if it was revoked.

---

## Networking

- All desktop API calls go through `DesktopApiService` with a **10-second HTTP timeout**.
- Each call sends `X-Pair-Token: <token>` for the selected desktop.
- The active desktop (for single-device views) is chosen in the profile tab.
- "All Devices" mode fans out to every paired desktop in parallel and merges results.

### Handling connection failures

- Unreachable desktop → the row is marked offline in the device picker; the last known data stays visible.
- Corrupted saved-device JSON (from older app versions) is caught and ignored on load instead of crashing the app.

---

## Refresh behavior

- While **foregrounded**: auto-refresh every 30 s.
- On **background** (Flutter `AppLifecycleState.paused`): timer stops.
- On **foreground** (`resumed`): immediate refresh, then resume 30 s cadence.

Pull-to-refresh works on every list/dashboard screen for on-demand refresh.

---

## Categories

Three buckets: **productive**, **neutral**, **distraction**.

- Stored per-app in SharedPreferences on the phone.
- When paired with a desktop, category changes also `PUT /usage/apps/{name}/category` so the desktop agrees.
- The dashboard's productive/distraction split reflects local overrides first, then the desktop's stored category.

---

## Icons & favicons

- **Apps:** ~20 popular apps have hand-picked icons (Chrome, Instagram, YouTube, …). Everything else falls back to a letter avatar colored by a hash of the app name.
- **Websites:** favicons fetched from `https://www.google.com/s2/favicons?domain=<domain>&sz=64` and cached by Flutter's image cache.

---

## Build commands

```bash
# Dev (only if you have headroom on the device)
flutter run

# Release APK (preferred for the test device)
flutter build apk --release

# Install pre-built APK to a specific device
flutter install -d RZCX92JRFCH

# Analyze / lint
flutter analyze
```

Android build output: `build/app/outputs/flutter-apk/app-release.apk`.

---

## Troubleshooting

**"No usage data" on the Dashboard phone card.**
Usage Access permission is off. Profile → Permissions → enable for Trace Your Lyf, then pull-to-refresh.

**Paired desktop shows as offline.**
- Is the desktop actually running? Check the tray icon.
- Same Wi-Fi network on both devices?
- macOS firewall may be blocking inbound port 8742.
- The phone's IP of the desktop may have changed (DHCP). Re-pair or update the stored IP.

**Pairing fails with "Invalid code".**
Codes rotate every 2 hours on the desktop. Read the current one from the tray menu.

**App crashes on launch after an update.**
Clear app storage (Settings → Apps → Trace Your Lyf → Storage → Clear data). This wipes paired desktops and categories.

---

## Next steps

Tracked in the project memory, not firm commitments:

- QR-code scanning for pairing (no typing IP/port).
- Optional real auth / account system.
- Mobile-to-mobile sync (phone + tablet sharing).
- Notification reminders / goal nudges.
- iOS — blocked on Apple API access.
