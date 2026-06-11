# TODO - Cross-Platform Key Metadata Monitor

Status values: Not Started | In Progress | Blocked | Done

## Operation 1 - Windows app (same purpose as mac app)

| ID | Task | Status |
|---|---|---|
| W1 | Finalize parity requirements (metadata-only, no typed text reconstruction) | Done |
| W2 | Create Windows project scaffold (.NET 8 + WPF) | Done |
| W3 | Implement global key capture (WH_KEYBOARD_LL) metadata-only | Done |
| W4 | Implement active app and window title enrichment | Done |
| W5 | Implement local SQLite persistence | Done |
| W6 | Implement recent event list UI + ON/OFF capture controls | Done |
| W7 | Implement clear log and JSON export | Done |
| W8 | Add retention policy (default 7 days) | Done |
| W9 | Add README and privacy guardrails | Done |
| W10 | Validate build/test on Windows 10/11 | Not Started |

## Operation 2 - Device-aware download website

| ID | Task | Status |
|---|---|---|
| S1 | Create responsive landing page scaffold | Done |
| S2 | Implement platform detection (Windows/macOS/Linux/unknown) | Done |
| S3 | Wire primary smart download CTA | Done |
| S4 | Add manual platform selector fallback | Done |
| S5 | Add versioned release manifest for download links | Done |
| S6 | Add install help and checksum/signature section | Done |
| S7 | Add deployment instructions | Done |

## Integration

| ID | Task | Status |
|---|---|---|
| I1 | Connect app release artifacts to site manifest links | In Progress |
| I2 | End-to-end QA across browsers/devices | Not Started |
| I3 | Launch checklist and maintenance workflow | Not Started |

## Operation 3 - Central backend API

| ID | Task | Status |
|---|---|---|
| B1 | Scaffold central ingest/analysis API | Done |
| B2 | Add local central SQLite storage | Done |
| B3 | Add session ingest endpoint | Done |
| B4 | Add analysis summary/events endpoints | Done |
| B5 | Validate ingest + analysis locally | Done |
| B6 | Add client upload wiring in apps | Done |
| B7 | Add authentication and transport security | Not Started |
