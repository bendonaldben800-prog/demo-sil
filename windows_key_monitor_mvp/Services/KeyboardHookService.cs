using System;
using System.Runtime.InteropServices;
using WindowsKeyMonitorMvp.Models;

namespace WindowsKeyMonitorMvp.Services;

public sealed class KeyboardHookService : IDisposable
{
    private const int WhKeyboardLl = 13;
    private const int WmKeyDown = 0x0100;
    private const int WmSysKeyDown = 0x0104;

    private readonly ActiveWindowService _activeWindowService;
    private readonly HookProc _hookProc;

    private IntPtr _hookHandle = IntPtr.Zero;

    public event Action<KeyEventMetadata>? EventCaptured;

    public KeyboardHookService(ActiveWindowService activeWindowService)
    {
        _activeWindowService = activeWindowService;
        _hookProc = HookCallback;
    }

    public bool IsRunning => _hookHandle != IntPtr.Zero;

    public void Start()
    {
        if (IsRunning)
        {
            return;
        }

        using var process = System.Diagnostics.Process.GetCurrentProcess();
        using var module = process.MainModule;
        var moduleName = module?.ModuleName;

        var moduleHandle = moduleName is null ? IntPtr.Zero : GetModuleHandle(moduleName);
        _hookHandle = SetWindowsHookEx(WhKeyboardLl, _hookProc, moduleHandle, 0);

        if (_hookHandle == IntPtr.Zero)
        {
            throw new InvalidOperationException("Unable to start global keyboard hook.");
        }
    }

    public void Stop()
    {
        if (!IsRunning)
        {
            return;
        }

        _ = UnhookWindowsHookEx(_hookHandle);
        _hookHandle = IntPtr.Zero;
    }

    public void Dispose()
    {
        Stop();
        GC.SuppressFinalize(this);
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var message = wParam.ToInt32();
            if (message == WmKeyDown || message == WmSysKeyDown)
            {
                var hookStruct = Marshal.PtrToStructure<KbdLlHookStruct>(lParam);
                var (appName, windowTitle) = _activeWindowService.GetForegroundWindowInfo();

                var keyCode = (int)hookStruct.vkCode;
                var ev = new KeyEventMetadata(
                    Timestamp: DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0,
                    KeyCode: keyCode,
                    KeyIdentifier: keyCode.ToString(),
                    ModCommand: IsKeyDown(VK_LWIN) || IsKeyDown(VK_RWIN),
                    ModShift: IsKeyDown(VK_SHIFT),
                    ModOption: IsKeyDown(VK_MENU),
                    ModControl: IsKeyDown(VK_CONTROL),
                    ActiveAppName: appName,
                    ActiveWindowTitle: windowTitle
                );

                EventCaptured?.Invoke(ev);
            }
        }

        return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    private static bool IsKeyDown(int virtualKey)
    {
        return (GetKeyState(virtualKey) & 0x8000) != 0;
    }

    private const int VK_SHIFT = 0x10;
    private const int VK_CONTROL = 0x11;
    private const int VK_MENU = 0x12;
    private const int VK_LWIN = 0x5B;
    private const int VK_RWIN = 0x5C;

    private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct KbdLlHookStruct
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("user32.dll")]
    private static extern short GetKeyState(int nVirtKey);
}
