import express from "express";
import cors from "cors";
import Database from "better-sqlite3";
import path from "node:path";
import fs from "node:fs";

const PORT = Number(process.env.PORT || 8787);
const DATA_DIR = process.env.DATA_DIR || path.resolve(process.cwd(), "data");
const DB_PATH = path.join(DATA_DIR, "central-events.sqlite");
const DEFAULT_UPLOAD_ENABLED = parseBool(process.env.DEFAULT_UPLOAD_ENABLED, true);
const DEFAULT_UPLOAD_INTERVAL_SECONDS = clampInt(
  Number(process.env.DEFAULT_UPLOAD_INTERVAL_SECONDS || 120),
  30,
  3600,
);

fs.mkdirSync(DATA_DIR, { recursive: true });

const db = new Database(DB_PATH);
db.pragma("journal_mode = WAL");

db.exec(`
CREATE TABLE IF NOT EXISTS devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL UNIQUE,
  platform TEXT,
  app_version TEXT,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL UNIQUE,
  device_id TEXT NOT NULL,
  started_at REAL NOT NULL,
  stopped_at REAL,
  source TEXT,
  received_at REAL NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

CREATE TABLE IF NOT EXISTS device_configs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL UNIQUE,
  upload_enabled INTEGER,
  upload_interval_seconds INTEGER,
  updated_at REAL NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

CREATE TABLE IF NOT EXISTS key_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  ts REAL NOT NULL,
  key_code INTEGER,
  key_identifier TEXT,
  mod_command INTEGER,
  mod_shift INTEGER,
  mod_option INTEGER,
  mod_control INTEGER,
  mod_caps_lock INTEGER,
  active_app_bundle_id TEXT,
  active_app_name TEXT,
  active_window_title TEXT,
  FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

CREATE INDEX IF NOT EXISTS idx_key_events_ts ON key_events(ts);
CREATE INDEX IF NOT EXISTS idx_key_events_session_id ON key_events(session_id);
CREATE INDEX IF NOT EXISTS idx_sessions_device_id ON sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_device_configs_device_id ON device_configs(device_id);
`);

const upsertDeviceStmt = db.prepare(`
INSERT INTO devices (device_id, platform, app_version, created_at, updated_at)
VALUES (@deviceId, @platform, @appVersion, @now, @now)
ON CONFLICT(device_id) DO UPDATE SET
  platform = COALESCE(excluded.platform, devices.platform),
  app_version = COALESCE(excluded.app_version, devices.app_version),
  updated_at = excluded.updated_at;
`);

const insertSessionStmt = db.prepare(`
INSERT INTO sessions (session_id, device_id, started_at, stopped_at, source, received_at)
VALUES (@sessionId, @deviceId, @startedAt, @stoppedAt, @source, @receivedAt)
ON CONFLICT(session_id) DO UPDATE SET
  stopped_at = COALESCE(excluded.stopped_at, sessions.stopped_at),
  source = COALESCE(excluded.source, sessions.source),
  received_at = excluded.received_at;
`);

const clearSessionEventsStmt = db.prepare("DELETE FROM key_events WHERE session_id = ?;");

const insertEventStmt = db.prepare(`
INSERT INTO key_events (
  session_id, ts, key_code, key_identifier,
  mod_command, mod_shift, mod_option, mod_control, mod_caps_lock,
  active_app_bundle_id, active_app_name, active_window_title
) VALUES (
  @sessionId, @ts, @keyCode, @keyIdentifier,
  @modCommand, @modShift, @modOption, @modControl, @modCapsLock,
  @activeAppBundleID, @activeAppName, @activeWindowTitle
);
`);

const getDeviceConfigStmt = db.prepare(`
SELECT upload_enabled AS uploadEnabled, upload_interval_seconds AS uploadIntervalSeconds
FROM device_configs
WHERE device_id = ?;
`);

const upsertDeviceConfigStmt = db.prepare(`
INSERT INTO device_configs (device_id, upload_enabled, upload_interval_seconds, updated_at)
VALUES (@deviceId, @uploadEnabled, @uploadIntervalSeconds, @updatedAt)
ON CONFLICT(device_id) DO UPDATE SET
  upload_enabled = COALESCE(excluded.upload_enabled, device_configs.upload_enabled),
  upload_interval_seconds = COALESCE(excluded.upload_interval_seconds, device_configs.upload_interval_seconds),
  updated_at = excluded.updated_at;
`);

const ingestSessionTx = db.transaction((payload) => {
  const now = Date.now() / 1000;

  const deviceId = String(payload.deviceId || "unknown-device");
  const sessionId = String(payload.sessionId || `${deviceId}-${Math.floor(now)}`);

  upsertDeviceStmt.run({
    deviceId,
    platform: payload.platform || null,
    appVersion: payload.appVersion || null,
    now,
  });

  insertSessionStmt.run({
    sessionId,
    deviceId,
    startedAt: Number(payload.startedAt || now),
    stoppedAt: payload.stoppedAt == null ? null : Number(payload.stoppedAt),
    source: payload.source || null,
    receivedAt: now,
  });

  clearSessionEventsStmt.run(sessionId);

  const events = Array.isArray(payload.events) ? payload.events : [];
  for (const ev of events) {
    const modifiers = ev.modifiers || {};

    insertEventStmt.run({
      sessionId,
      ts: Number(ev.ts || now),
      keyCode: ev.keyCode == null ? null : Number(ev.keyCode),
      keyIdentifier: ev.keyIdentifier || null,
      modCommand: Number(boolToInt(modifiers.command ?? ev.modCommand)),
      modShift: Number(boolToInt(modifiers.shift ?? ev.modShift)),
      modOption: Number(boolToInt(modifiers.option ?? ev.modOption)),
      modControl: Number(boolToInt(modifiers.control ?? ev.modControl)),
      modCapsLock: modifiers.capsLock == null ? null : Number(boolToInt(modifiers.capsLock)),
      activeAppBundleID: ev.activeAppBundleID || null,
      activeAppName: ev.activeAppName || null,
      activeWindowTitle: ev.activeWindowTitle || null,
    });
  }

  return { sessionId, deviceId, insertedEvents: events.length };
});

const app = express();
app.use(cors());
app.use(express.json({ limit: "5mb" }));

app.get("/health", (_req, res) => {
  res.json({ ok: true, dbPath: DB_PATH, time: new Date().toISOString() });
});

app.post("/api/v1/ingest/session", (req, res) => {
  try {
    const payload = req.body || {};

    if (!payload.events || !Array.isArray(payload.events)) {
      return res.status(400).json({ error: "Payload must include an events array." });
    }

    const out = ingestSessionTx(payload);
    return res.status(201).json({ ok: true, ...out });
  } catch (error) {
    return res.status(500).json({ error: "Failed to ingest session", details: String(error) });
  }
});

app.get("/api/v1/client-config", (req, res) => {
  try {
    const deviceId = String(req.query.deviceId || "").trim();
    const row = deviceId ? getDeviceConfigStmt.get(deviceId) : null;

    const uploadEnabled = row?.uploadEnabled == null
      ? DEFAULT_UPLOAD_ENABLED
      : row.uploadEnabled !== 0;

    const uploadIntervalSeconds = clampInt(
      row?.uploadIntervalSeconds == null
        ? DEFAULT_UPLOAD_INTERVAL_SECONDS
        : Number(row.uploadIntervalSeconds),
      30,
      3600,
    );

    return res.json({
      uploadEnabled,
      uploadIntervalSeconds,
      minIntervalSeconds: 30,
      maxIntervalSeconds: 3600,
      ingestPath: "/api/v1/ingest/session",
    });
  } catch (error) {
    return res.status(500).json({ error: "Failed to read client config", details: String(error) });
  }
});

app.put("/api/v1/admin/device-config/:deviceId", (req, res) => {
  try {
    const deviceId = String(req.params.deviceId || "").trim();
    if (!deviceId) {
      return res.status(400).json({ error: "deviceId is required" });
    }

    const uploadEnabled = req.body?.uploadEnabled;
    const uploadIntervalSeconds = req.body?.uploadIntervalSeconds;

    upsertDeviceConfigStmt.run({
      deviceId,
      uploadEnabled: uploadEnabled == null ? null : boolToInt(Boolean(uploadEnabled)),
      uploadIntervalSeconds:
        uploadIntervalSeconds == null ? null : clampInt(Number(uploadIntervalSeconds), 30, 3600),
      updatedAt: Date.now() / 1000,
    });

    const row = getDeviceConfigStmt.get(deviceId);
    return res.json({
      ok: true,
      deviceId,
      uploadEnabled: row?.uploadEnabled == null ? DEFAULT_UPLOAD_ENABLED : row.uploadEnabled !== 0,
      uploadIntervalSeconds:
        row?.uploadIntervalSeconds == null
          ? DEFAULT_UPLOAD_INTERVAL_SECONDS
          : clampInt(Number(row.uploadIntervalSeconds), 30, 3600),
    });
  } catch (error) {
    return res.status(500).json({ error: "Failed to update device config", details: String(error) });
  }
});

app.get("/api/v1/analysis/summary", (_req, res) => {
  try {
    const totalEvents = db.prepare("SELECT COUNT(*) AS count FROM key_events;").get().count;
    const totalSessions = db.prepare("SELECT COUNT(*) AS count FROM sessions;").get().count;
    const totalDevices = db.prepare("SELECT COUNT(*) AS count FROM devices;").get().count;

    const topApps = db
      .prepare(`
        SELECT COALESCE(active_app_name, 'unknown') AS appName, COUNT(*) AS events
        FROM key_events
        GROUP BY COALESCE(active_app_name, 'unknown')
        ORDER BY events DESC
        LIMIT 10;
      `)
      .all();

    const topKeys = db
      .prepare(`
        SELECT COALESCE(key_identifier, 'unknown') AS keyIdentifier, COUNT(*) AS events
        FROM key_events
        GROUP BY COALESCE(key_identifier, 'unknown')
        ORDER BY events DESC
        LIMIT 10;
      `)
      .all();

    const recentSessions = db
      .prepare(`
        SELECT session_id AS sessionId, device_id AS deviceId, started_at AS startedAt, stopped_at AS stoppedAt, source
        FROM sessions
        ORDER BY received_at DESC
        LIMIT 20;
      `)
      .all();

    res.json({
      totals: {
        events: totalEvents,
        sessions: totalSessions,
        devices: totalDevices,
      },
      topApps,
      topKeys,
      recentSessions,
    });
  } catch (error) {
    res.status(500).json({ error: "Failed to compute summary", details: String(error) });
  }
});

app.get("/api/v1/analysis/events", (req, res) => {
  try {
    const limit = Math.min(Math.max(Number(req.query.limit || 100), 1), 5000);
    const rows = db
      .prepare(`
        SELECT
          session_id AS sessionId,
          ts,
          key_code AS keyCode,
          key_identifier AS keyIdentifier,
          mod_command AS modCommand,
          mod_shift AS modShift,
          mod_option AS modOption,
          mod_control AS modControl,
          mod_caps_lock AS modCapsLock,
          active_app_bundle_id AS activeAppBundleID,
          active_app_name AS activeAppName,
          active_window_title AS activeWindowTitle
        FROM key_events
        ORDER BY ts DESC
        LIMIT ?;
      `)
      .all(limit);

    res.json({ count: rows.length, events: rows });
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch events", details: String(error) });
  }
});

app.listen(PORT, () => {
  console.log(`Central backend API listening on http://localhost:${PORT}`);
  console.log(`SQLite path: ${DB_PATH}`);
});

function boolToInt(value) {
  return value ? 1 : 0;
}

function parseBool(value, fallback) {
  if (value == null) {
    return fallback;
  }
  const normalized = String(value).trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "off"].includes(normalized)) {
    return false;
  }
  return fallback;
}

function clampInt(value, min, max) {
  if (!Number.isFinite(value)) {
    return min;
  }
  return Math.min(Math.max(Math.round(value), min), max);
}
