namespace WindowsKeyMonitorMvp.Models;

public sealed class ClientUploadConfig
{
    public bool UploadEnabled { get; set; } = true;
    public int UploadIntervalSeconds { get; set; } = 120;
}
