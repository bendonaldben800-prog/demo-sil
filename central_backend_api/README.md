# Central Backend API

Central ingestion and analysis API for key metadata sessions from macOS and Windows clients.

## Features

- Session ingest endpoint with payload shape compatible with current apps
- Local SQLite central storage
- Summary and event analysis endpoints
- CORS enabled for dashboard or analysis tooling

## Endpoints

- `GET /health`
- `POST /api/v1/ingest/session`
- `GET /api/v1/client-config?deviceId=<device-id>`
- `PUT /api/v1/admin/device-config/:deviceId`
- `GET /api/v1/analysis/summary`
- `GET /api/v1/analysis/events?limit=100`

## Client integration (current apps)

Both clients can post exported session JSON directly to:

- `POST /api/v1/ingest/session`

The backend accepts the existing mac payload shape (`startedAt`, `stoppedAt`, `events` with `modifiers`) and also supports flattened modifier fields used by Windows (`modCommand`, `modShift`, `modOption`, `modControl`).

Example curl upload:

```bash
curl -X POST http://localhost:8787/api/v1/ingest/session \
  -H "Content-Type: application/json" \
  -d @/path/to/exported-session.json
```

Recommended extra envelope fields for central analysis:

- `deviceId` (required for multi-device attribution)
- `platform` (`macos` or `windows`)
- `appVersion`
- `source`
- `sessionId`

## Quick start

```bash
cd central_backend_api
npm install
npm start
```

Default URL: `http://localhost:8787`

## Data location

By default, SQLite database file is stored at:

- `central_backend_api/data/central-events.sqlite`

Override with env var:

```bash
DATA_DIR=/absolute/path npm start
```

## Ingest payload example

```json
{
  "deviceId": "macbook-01",
  "platform": "macos",
  "appVersion": "0.1.0",
  "source": "system_wide_key_monitor_mvp",
  "sessionId": "session-2026-06-10-001",
  "startedAt": 1717990000.12,
  "stoppedAt": 1717990300.49,
  "events": [
    {
      "ts": 1717990001.23,
      "keyCode": 12,
      "keyIdentifier": "12",
      "modifiers": {
        "command": false,
        "shift": true,
        "option": false,
        "control": false,
        "capsLock": null
      },
      "activeAppBundleID": "com.apple.Safari",
      "activeAppName": "Safari",
      "activeWindowTitle": "Example"
    }
  ]
}
```

## Notes

- Current implementation is intentionally simple for MVP analysis workflows.
- Add auth, encryption, and rate limiting before production use.

## Backend-controlled upload interval

Clients fetch upload policy from `GET /api/v1/client-config`.

Default behavior:

- `uploadEnabled = true`
- `uploadIntervalSeconds = 120`

You can override a specific device with:

```bash
curl -X PUT http://localhost:8787/api/v1/admin/device-config/demo-device-01 \
  -H "Content-Type: application/json" \
  -d '{"uploadEnabled": true, "uploadIntervalSeconds": 180}'
```

## Local validation done

Tested successfully on June 10, 2026:

- `GET /health`
- `POST /api/v1/ingest/session`
- `GET /api/v1/analysis/summary`
- `GET /api/v1/analysis/events?limit=5`
