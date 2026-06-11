using System.Collections.Generic;

namespace WindowsKeyMonitorMvp.Models;

public sealed class SessionUploadPayload
{
    public string DeviceId { get; set; } = "unknown-device";
    public string Platform { get; set; } = "windows";
    public string AppVersion { get; set; } = "0.1.0";
    public string Source { get; set; } = "windows_key_monitor_mvp";
    public string SessionId { get; set; } = string.Empty;
    public double StartedAt { get; set; }
    public double? StoppedAt { get; set; }
    public List<KeyEventMetadata> Events { get; set; } = new();
}
