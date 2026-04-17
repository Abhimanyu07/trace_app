# Trace Your Lyf — Desktop

Python 3 daemon that runs in the macOS menu bar, tracks the active window every 2 seconds, and exposes the data over a local HTTP API so the mobile app (or any other client on your LAN) can read it.

---

## What it tracks

Every 2 seconds the tracker polls the frontmost application via AppleScript and records:

| Field             | Source                                                   |
|-------------------|----------------------------------------------------------|
| App name          | `System Events` frontmost process                        |
| Window title      | `System Events` frontmost window title                   |
| Browser URL       | Per-browser AppleScript (Chrome / Safari / Arc / Edge / Brave) |
| IDE project       | Parsed from window title (VS Code, Cursor, JetBrains)    |
| Start / end time  | Epoch seconds                                            |
| Duration          | end − start (records < 3 s are dropped)                  |

**Firefox is not supported** — it has no AppleScript API for the current URL.

The tracker auto-pauses when the screen is locked (detected via `CGSessionCopyCurrentDictionary`) and after 5 minutes of idle.

---

## Install & run

```bash
cd trace_app
pip install -r desktop/requirements.txt
python3 -m desktop.main
```

`requirements.txt`:
- `fastapi` — HTTP API
- `uvicorn` — ASGI server
- `pystray` — system tray icon
- `Pillow` — tray icon image
- `psutil` — process info

### Permissions (macOS)

On first run, macOS will prompt for:

1. **Accessibility** — needed for `System Events` to read the active app.
2. **Screen Recording** — required to read window titles on macOS 10.15+.

If the tracker starts but every record has an empty title, you didn't grant Screen Recording. Go to **System Settings → Privacy & Security → Screen Recording**, enable Terminal (or whatever you ran Python from), and restart.

---

## Running as a background service

The script is foreground-only for now. To run it on login, wrap it in a `launchd` plist:

```xml
<!-- ~/Library/LaunchAgents/com.traceyourlyf.desktop.plist -->
<plist version="1.0">
<dict>
  <key>Label</key><string>com.traceyourlyf.desktop</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>-m</string>
    <string>desktop.main</string>
  </array>
  <key>WorkingDirectory</key><string>/ABSOLUTE/PATH/TO/trace_app</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
```

Then `launchctl load ~/Library/LaunchAgents/com.traceyourlyf.desktop.plist`.

---

## Project layout

```
desktop/
├── main.py              entry point: DB init, tray, API server, pair-code rotation
├── config.py            paths, port, poll interval, pairing-code generator
├── tracker/
│   └── macos.py         AppleScript window poller, idle detection, lock detection
├── api/
│   ├── server.py        FastAPI app + auth middleware (X-Pair-Token)
│   ├── routes_pairing.py  /pair/* endpoints
│   └── routes_usage.py    /usage/* endpoints
├── db/
│   └── database.py      SQLite schema + queries (WAL mode, context-managed conns)
├── tray/
│   └── tray_app.py      pystray menu: IP, pair code, pause toggle, quit
└── utils/
    └── network.py       get_local_ip()
```

Data lives in `~/.traceyourlyf/`:

| File          | Purpose                                        |
|---------------|------------------------------------------------|
| `tracker.db`  | SQLite: usage records, categories, paired devices, pairing code |
| `device_id`   | Stable 8-char UUID slice for this machine       |

---

## HTTP API

Base URL: `http://<local-ip>:8742`

Auth: every request except `/health`, `/pair/*`, and the OpenAPI docs must include the header `X-Pair-Token: <token>` issued by `POST /pair`. Invalid or missing tokens return `401`.

### Pairing

| Method | Path              | Body / Query                         | Returns                                           |
|--------|-------------------|--------------------------------------|---------------------------------------------------|
| GET    | `/pair/code`      | —                                    | current 6-digit code, device id/name, ip, port    |
| POST   | `/pair`           | `{code, device_name, device_id, device_type}` | `{success, token, device_id, device_name, ...}` |
| GET    | `/pair/devices`   | —                                    | list of paired devices                            |
| POST   | `/pair/unpair`    | `{token}`                            | `{success: true}`                                 |
| GET    | `/pair/status`    | —                                    | device info + paired count                        |
| GET    | `/pair/qr-data`   | —                                    | ip, port, code, device_id (for QR rendering)      |

The pairing code rotates every **2 hours**. Existing tokens keep working.

### Usage

| Method | Path                                  | Query                       | Returns                                  |
|--------|---------------------------------------|-----------------------------|------------------------------------------|
| GET    | `/usage/today`                        | —                           | today's records                          |
| GET    | `/usage/range`                        | `start=YYYY-MM-DD&end=…`    | records in range                         |
| GET    | `/usage/summary/daily`                | `date=YYYY-MM-DD` (optional)| aggregated per-app for day               |
| GET    | `/usage/summary/weekly`               | `week_start=YYYY-MM-DD`     | 7 days, Monday-anchored                  |
| GET    | `/usage/hourly`                       | `date=YYYY-MM-DD`           | 24-bucket breakdown                      |
| GET    | `/usage/apps`                         | —                           | all apps ever seen, with category        |
| GET    | `/usage/domains`                      | —                           | all browsed domains                      |
| PUT    | `/usage/apps/{app_name}/category`     | `{category: "productive" \| "neutral" \| "distraction"}` | `{success: true}` |
| GET    | `/usage/current`                      | —                           | current active window, or `active: false`|
| GET    | `/usage/status`                       | —                           | `{is_paused}`                            |

Every `/usage/*` response includes `device_id`, `device_name`, `device_type: "desktop"` so the phone can attribute rows to the right machine.

### Miscellaneous

- `GET /health` — `{status: "ok", version}`. No auth.
- `GET /docs` — Swagger UI. No auth.

---

## Tray menu

```
Trace Your Lyf
─────────────
IP: 192.168.x.x:8742
Code: 123456
─────────────
⏸  Pause tracking     (or ▶  Resume)
✕  Quit
```

**Pause** stops the poll loop immediately; the current record is finalized. **Resume** starts a fresh record on the next tick.

---

## Database

SQLite with WAL mode for concurrent reads from the API thread while the tracker thread writes.

Key tables (see `db/database.py` for exact schema):

- `usage_records` — one row per contiguous window session (`app_name`, `window_title`, `url`, `project`, `start_ts`, `end_ts`, `duration_seconds`).
- `apps` — app name → category.
- `paired_devices` — `token`, `device_name`, `device_id`, `device_type`, `paired_at`.
- `pairing` — single-row table holding the current code.

Date boundaries are computed with local-time `datetime` arithmetic to stay correct across DST transitions.

Connections are acquired via a `get_db()` context manager so they're always closed — avoiding the connection-leak bug that shipped in 0.1.

---

## Troubleshooting

**Tray icon doesn't appear.**
`pystray` needs a GUI session. If you're running over SSH, it won't work; use `launchd` or run in the local session.

**Records have empty `window_title`.**
Grant **Screen Recording** permission and restart Python.

**Phone says "connection refused".**
- Both devices on the same LAN?
- macOS firewall blocking port 8742? System Settings → Network → Firewall → Options → allow Python.
- Confirm the IP shown in the tray matches the one the phone is trying to reach.

**Pairing code doesn't work.**
It rotates every 2 hours. Check the current code in the tray menu.

**Browser URLs missing.**
Firefox is not supported. For other browsers, make sure that specific browser is in the allow-list in `config.py` (`BROWSER_APPS`).

---

## Extending

- **Add a browser:** append its app name to `BROWSER_APPS` in `config.py` and add an AppleScript branch in `tracker/macos.py`.
- **Add an IDE:** append to `IDE_APPS` and extend the project-name parser in `tracker/macos.py`.
- **Port to Linux / Windows:** implement a new tracker module with the same public interface as `tracker/macos.py` (`start`, `stop`, `pause`, `resume`, `get_current`, `is_paused`) and swap the import in `main.py`.
