using System;
using System.Collections.Generic;
using Microsoft.Data.Sqlite;
using WindowsKeyMonitorMvp.Models;

namespace WindowsKeyMonitorMvp.Services;

public sealed class EventRepository
{
    private readonly string _connectionString;

    public EventRepository(string databasePath)
    {
        _connectionString = $"Data Source={databasePath}";
        EnsureSchema();
    }

    public void Insert(KeyEventMetadata ev)
    {
        using var connection = new SqliteConnection(_connectionString);
        connection.Open();

        using var cmd = connection.CreateCommand();
        cmd.CommandText =
            """
            INSERT INTO key_events (
                ts, key_code, key_identifier,
                mod_command, mod_shift, mod_option, mod_control,
                active_app_name, active_window_title
            ) VALUES ($ts, $key_code, $key_identifier, $mod_command, $mod_shift, $mod_option, $mod_control, $active_app_name, $active_window_title);
            """;

        cmd.Parameters.AddWithValue("$ts", ev.Timestamp);
        cmd.Parameters.AddWithValue("$key_code", ev.KeyCode);
        cmd.Parameters.AddWithValue("$key_identifier", ev.KeyIdentifier);
        cmd.Parameters.AddWithValue("$mod_command", ev.ModCommand ? 1 : 0);
        cmd.Parameters.AddWithValue("$mod_shift", ev.ModShift ? 1 : 0);
        cmd.Parameters.AddWithValue("$mod_option", ev.ModOption ? 1 : 0);
        cmd.Parameters.AddWithValue("$mod_control", ev.ModControl ? 1 : 0);
        cmd.Parameters.AddWithValue("$active_app_name", (object?)ev.ActiveAppName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$active_window_title", (object?)ev.ActiveWindowTitle ?? DBNull.Value);
        _ = cmd.ExecuteNonQuery();
    }

    public List<KeyEventMetadata> FetchRecent(int limit)
    {
        var outList = new List<KeyEventMetadata>();

        using var connection = new SqliteConnection(_connectionString);
        connection.Open();

        using var cmd = connection.CreateCommand();
        cmd.CommandText =
            """
            SELECT
                ts, key_code, key_identifier,
                mod_command, mod_shift, mod_option, mod_control,
                active_app_name, active_window_title
            FROM key_events
            ORDER BY ts DESC
            LIMIT $limit;
            """;
        cmd.Parameters.AddWithValue("$limit", Math.Max(1, limit));

        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            outList.Add(ReadEvent(reader));
        }

        outList.Reverse();
        return outList;
    }

    public List<KeyEventMetadata> FetchAll()
    {
        var outList = new List<KeyEventMetadata>();

        using var connection = new SqliteConnection(_connectionString);
        connection.Open();

        using var cmd = connection.CreateCommand();
        cmd.CommandText =
            """
            SELECT
                ts, key_code, key_identifier,
                mod_command, mod_shift, mod_option, mod_control,
                active_app_name, active_window_title
            FROM key_events
            ORDER BY ts ASC;
            """;

        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            outList.Add(ReadEvent(reader));
        }

        return outList;
    }

    public int Count()
    {
        using var connection = new SqliteConnection(_connectionString);
        connection.Open();

        using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM key_events;";
        return Convert.ToInt32(cmd.ExecuteScalar());
    }

    public void Clear()
    {
        using var connection = new SqliteConnection(_connectionString);
        connection.Open();

        using var cmd = connection.CreateCommand();
        cmd.CommandText = "DELETE FROM key_events;";
        _ = cmd.ExecuteNonQuery();
    }

    public void DeleteOlderThan(double cutoffTimestamp)
    {
        using var connection = new SqliteConnection(_connectionString);
        connection.Open();

        using var cmd = connection.CreateCommand();
        cmd.CommandText = "DELETE FROM key_events WHERE ts < $cutoff;";
        cmd.Parameters.AddWithValue("$cutoff", cutoffTimestamp);
        _ = cmd.ExecuteNonQuery();
    }

    private void EnsureSchema()
    {
        using var connection = new SqliteConnection(_connectionString);
        connection.Open();

        using var cmd = connection.CreateCommand();
        cmd.CommandText =
            """
            CREATE TABLE IF NOT EXISTS key_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts REAL NOT NULL,
                key_code INTEGER NOT NULL,
                key_identifier TEXT NOT NULL,
                mod_command INTEGER NOT NULL,
                mod_shift INTEGER NOT NULL,
                mod_option INTEGER NOT NULL,
                mod_control INTEGER NOT NULL,
                active_app_name TEXT,
                active_window_title TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_key_events_ts ON key_events(ts);
            """;
        _ = cmd.ExecuteNonQuery();
    }

    private static KeyEventMetadata ReadEvent(SqliteDataReader reader)
    {
        return new KeyEventMetadata(
            Timestamp: reader.GetDouble(0),
            KeyCode: reader.GetInt32(1),
            KeyIdentifier: reader.GetString(2),
            ModCommand: reader.GetInt32(3) != 0,
            ModShift: reader.GetInt32(4) != 0,
            ModOption: reader.GetInt32(5) != 0,
            ModControl: reader.GetInt32(6) != 0,
            ActiveAppName: reader.IsDBNull(7) ? null : reader.GetString(7),
            ActiveWindowTitle: reader.IsDBNull(8) ? null : reader.GetString(8)
        );
    }
}
