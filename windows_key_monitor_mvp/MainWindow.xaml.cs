using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using Microsoft.Win32;
using WindowsKeyMonitorMvp.Models;
using WindowsKeyMonitorMvp.Services;

namespace WindowsKeyMonitorMvp;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<KeyEventMetadata> _recentEvents = new();
    private readonly ActiveWindowService _activeWindowService = new();
    private readonly KeyboardHookService _hookService;
    private readonly EventRepository _repository;
    private readonly UploadClient _uploadClient;
    private readonly HttpClient _httpClient = new();

    private readonly int _maxInMemoryEvents = 3000;
    private readonly TimeSpan _retentionWindow = TimeSpan.FromDays(7);

    private double? _sessionStart;
    private double? _sessionStop;
    private string? _sessionId;

    private readonly string _backendBaseUrl;
    private readonly string _deviceId;
    private DispatcherTimer? _uploadTimer;
    private int _uploadIntervalSeconds = 120;
    private bool _uploadEnabledByServer = true;

    public MainWindow()
    {
        InitializeComponent();

        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var appDir = Path.Combine(appData, "WindowsKeyMonitorMvp");
        Directory.CreateDirectory(appDir);

        _deviceId = GetOrCreateDeviceId(appDir);
        _backendBaseUrl = Environment.GetEnvironmentVariable("KEY_MONITOR_API_BASE_URL") ?? "http://localhost:8787";

        var dbPath = Path.Combine(appDir, "key-events.sqlite");
        _repository = new EventRepository(dbPath);
        _uploadClient = new UploadClient(_httpClient);

        _hookService = new KeyboardHookService(_activeWindowService);
        _hookService.EventCaptured += OnEventCaptured;

        LoadRecentEvents();
        UpdateStatusText($"Capture is OFF. Auto-upload backend: {_backendBaseUrl}");
    }

    private void CaptureToggle_Checked(object sender, RoutedEventArgs e)
    {
        try
        {
            _hookService.Start();
            _sessionStart ??= NowTs();
            _sessionId ??= Guid.NewGuid().ToString();
            _sessionStop = null;
            CaptureToggle.Content = "Capture ON";
            UpdateStatusText("Capture is ON (metadata-only, global).", false);
            _ = StartAutoUploadAsync();
        }
        catch (Exception ex)
        {
            CaptureToggle.IsChecked = false;
            UpdateStatusText($"Capture failed to start: {ex.Message}", true);
        }
    }

    private void CaptureToggle_Unchecked(object sender, RoutedEventArgs e)
    {
        _hookService.Stop();
        _sessionStop = NowTs();
        CaptureToggle.Content = "Capture OFF";
        UpdateStatusText("Capture is OFF.");
        StopAutoUpload();
    }

    private void ClearButton_Click(object sender, RoutedEventArgs e)
    {
        _repository.Clear();
        _recentEvents.Clear();
        EventsGrid.ItemsSource = null;
        EventsGrid.ItemsSource = _recentEvents;
        _sessionStart = null;
        _sessionStop = null;
        UpdateCountText();
        UpdateStatusText("Local log cleared.");
    }

    private void ExportButton_Click(object sender, RoutedEventArgs e)
    {
        var allEvents = _repository.FetchAll();
        if (allEvents.Count == 0)
        {
            UpdateStatusText("No stored events to export.", true);
            return;
        }

        var dialog = new SaveFileDialog
        {
            AddExtension = true,
            Filter = "JSON files (*.json)|*.json",
            FileName = $"key-events-{DateTime.UtcNow:yyyy-MM-ddTHH-mm-ssZ}.json"
        };

        var result = dialog.ShowDialog(this);
        if (result != true)
        {
            return;
        }

        var startedAt = _sessionStart ?? allEvents.First().Timestamp;
        JsonExportService.Export(dialog.FileName, startedAt, _sessionStop, allEvents);
        UpdateStatusText("Export complete.");
    }

    private void OnEventCaptured(KeyEventMetadata ev)
    {
        Dispatcher.Invoke(() =>
        {
            PruneByRetention();

            _repository.Insert(ev);
            _recentEvents.Add(ev);

            if (_recentEvents.Count > _maxInMemoryEvents)
            {
                _recentEvents.RemoveAt(0);
            }

            EventsGrid.ItemsSource = null;
            EventsGrid.ItemsSource = _recentEvents;
            UpdateCountText();
        });
    }

    private void LoadRecentEvents()
    {
        var list = _repository.FetchRecent(_maxInMemoryEvents);
        foreach (var ev in list)
        {
            _recentEvents.Add(ev);
        }

        EventsGrid.ItemsSource = _recentEvents;
        UpdateCountText();
    }

    private void PruneByRetention()
    {
        var cutoff = DateTimeOffset.UtcNow.Subtract(_retentionWindow).ToUnixTimeMilliseconds() / 1000.0;
        _repository.DeleteOlderThan(cutoff);
    }

    private static double NowTs()
    {
        return DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
    }

    private async Task StartAutoUploadAsync()
    {
        StopAutoUpload();
        await RefreshUploadConfigAsync();
        await PerformAutoUploadAsync();

        _uploadTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(Math.Max(30, _uploadIntervalSeconds))
        };

        _uploadTimer.Tick += async (_, _) =>
        {
            await RefreshUploadConfigAsync();
            await PerformAutoUploadAsync();
        };

        _uploadTimer.Start();
    }

    private void StopAutoUpload()
    {
        if (_uploadTimer is null)
        {
            return;
        }

        _uploadTimer.Stop();
        _uploadTimer = null;
    }

    private async Task RefreshUploadConfigAsync()
    {
        try
        {
            var config = await _uploadClient.FetchClientConfigAsync(_backendBaseUrl, _deviceId);
            _uploadEnabledByServer = config.UploadEnabled;
            _uploadIntervalSeconds = Math.Max(30, config.UploadIntervalSeconds);

            if (_uploadTimer is not null)
            {
                _uploadTimer.Interval = TimeSpan.FromSeconds(_uploadIntervalSeconds);
            }
        }
        catch (Exception ex)
        {
            UpdateStatusText($"Upload config fetch failed: {ex.Message}", true);
        }
    }

    private async Task PerformAutoUploadAsync()
    {
        if (!_uploadEnabledByServer)
        {
            UpdateStatusText("Capture ON. Auto-upload disabled by backend.");
            return;
        }

        if (_sessionStart is null || string.IsNullOrWhiteSpace(_sessionId))
        {
            return;
        }

        var events = _repository
            .FetchAll()
            .Where(ev => ev.Timestamp >= _sessionStart.Value)
            .ToList();

        if (events.Count == 0)
        {
            return;
        }

        var appVersion = Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "0.1.0";
        var payload = new SessionUploadPayload
        {
            DeviceId = _deviceId,
            Platform = "windows",
            AppVersion = appVersion,
            Source = "windows_key_monitor_mvp",
            SessionId = _sessionId,
            StartedAt = _sessionStart.Value,
            StoppedAt = _sessionStop,
            Events = events
        };

        try
        {
            await _uploadClient.UploadSessionAsync(_backendBaseUrl, payload);
            UpdateStatusText($"Capture ON. Uploaded {events.Count} event(s). Interval: {_uploadIntervalSeconds}s");
        }
        catch (Exception ex)
        {
            UpdateStatusText($"Upload failed: {ex.Message}", true);
        }
    }

    private static string GetOrCreateDeviceId(string appDir)
    {
        var path = Path.Combine(appDir, "device-id.txt");
        if (File.Exists(path))
        {
            var existing = File.ReadAllText(path).Trim();
            if (!string.IsNullOrWhiteSpace(existing))
            {
                return existing;
            }
        }

        var created = $"{Environment.MachineName}-{Guid.NewGuid()}";
        File.WriteAllText(path, created);
        return created;
    }

    private void UpdateCountText()
    {
        CountText.Text = $"Stored events: {_repository.Count()}";
    }

    private void UpdateStatusText(string message, bool isWarning = false)
    {
        StatusText.Text = message;
        StatusText.Foreground = isWarning
            ? System.Windows.Media.Brushes.DarkRed
            : System.Windows.Media.Brushes.DimGray;
    }

    protected override void OnClosed(EventArgs e)
    {
        StopAutoUpload();
        _hookService.EventCaptured -= OnEventCaptured;
        _httpClient.Dispose();
        _hookService.Dispose();
        base.OnClosed(e);
    }
}
