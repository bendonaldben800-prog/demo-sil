namespace WindowsKeyMonitorMvp.Models;

public sealed record KeyEventMetadata(
    double Timestamp,
    int KeyCode,
    string KeyIdentifier,
    bool ModCommand,
    bool ModShift,
    bool ModOption,
    bool ModControl,
    string? ActiveAppName,
    string? ActiveWindowTitle
);
