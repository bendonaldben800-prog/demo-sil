# System-wide Key Monitor (macOS)

## Purpose

Collect **system-wide key metadata** while the user explicitly enables capture.

## Capture scope (metadata only)

For each captured key event, the app records:

- timestamp
- key identity / code
- modifier state (Shift/Control/Option/Command/etc.)
- active application + active window title

## Not captured

- typed character sequences (no “Hello World” reconstruction)
- text field contents
- clipboard contents
- password/text entry content

## Privacy / notice

Capture is **off by default**.
The UI indicates when capture is ON and provides a clear Stop/Clear flow.

## Storage and retention

- Events are persisted locally in SQLite under the app's Application Support directory.
- The UI keeps a recent in-memory window for fast rendering.
- Users can clear local logs at any time.

## Export / retention

- Export captured events as JSON.
- Export reads from persisted local data.

## Auto upload

- The app now auto-uploads active session data to the central backend.
- Default interval is 120 seconds.
- Interval and enable/disable are controlled by backend endpoint `GET /api/v1/client-config`.
- Backend URL can be changed in the app UI under "Central backend".

## Build

Open the project in Xcode and run on macOS.

(Implementation files will be added in subsequent steps.)
