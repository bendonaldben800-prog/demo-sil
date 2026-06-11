using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace WindowsKeyMonitorMvp.Services;

public sealed class ActiveWindowService
{
    public (string? appName, string? windowTitle) GetForegroundWindowInfo()
    {
        var hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero)
        {
            return (null, null);
        }

        var title = GetWindowTitle(hwnd);
        var appName = GetProcessName(hwnd);
        return (appName, title);
    }

    private static string? GetWindowTitle(IntPtr hwnd)
    {
        var sb = new StringBuilder(512);
        _ = GetWindowText(hwnd, sb, sb.Capacity);
        var title = sb.ToString();
        return string.IsNullOrWhiteSpace(title) ? null : title;
    }

    private static string? GetProcessName(IntPtr hwnd)
    {
        _ = GetWindowThreadProcessId(hwnd, out var processId);
        if (processId == 0)
        {
            return null;
        }

        try
        {
            using var process = Process.GetProcessById((int)processId);
            return process.ProcessName;
        }
        catch
        {
            return null;
        }
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
