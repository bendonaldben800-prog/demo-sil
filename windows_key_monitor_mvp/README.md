# Windows Key Metadata Monitor (MVP)

A Windows MVP that mirrors the macOS app purpose: metadata-only global key monitoring.

## Captured

- timestamp
- key code and key identifier
- modifier state (Win/Cmd, Shift, Alt, Ctrl)
- active app/process name
- active window title

## Not captured

- typed text reconstruction
- text field content
- clipboard content
- passwords or message contents

## Storage and retention

- events are stored locally in SQLite under `%APPDATA%/WindowsKeyMonitorMvp/key-events.sqlite`
- in-memory recent list is used for fast UI rendering
- retention is currently 7 days by default

## Features in MVP

- Start/Stop metadata capture
- live recent event table
- clear local log
- export persisted events to JSON
- auto-upload to central backend every 120s by default
- backend-driven upload interval and enable/disable via `GET /api/v1/client-config`

## Build and run

1. Install .NET 8 SDK on Windows.
2. Open a terminal in this folder.
3. Run:

```bash
 dotnet restore
 dotnet run
```

## Notes

This is an ethical telemetry prototype. Keep users informed and obtain explicit consent before enabling capture.

Backend URL can be configured via environment variable on Windows:

`KEY_MONITOR_API_BASE_URL=http://your-backend-host:8787`
