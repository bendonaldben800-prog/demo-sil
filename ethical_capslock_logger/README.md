# Ethical Typing Logger (Local, In-Page)

This project demonstrates **ethical, non-covert** telemetry by recording **typing events generated within this page**.

## What this does

- Shows the current Caps Lock state in a small web UI.
- Records `keydown` events (including special keys) with timestamps.
- Records `input` events (insert/delete/paste behavior plus current field value).
- Provides an export button to download the captured events as JSON.

## What this does NOT do

- It does **not** do system-wide monitoring.
- It does **not** capture passwords or typed text.

The logger captures activity only while this page is open and focused.

## Important note

- Browsers restrict global keyboard access; this demo logs page-level events only.
- Use this in controlled environments where users are informed and have consented.

## Run

Open `index.html` in a browser.

Alternatively (if you add a local server):

- `python3 -m http.server 8000`
- open http://localhost:8000
