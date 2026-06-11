using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using WindowsKeyMonitorMvp.Models;

namespace WindowsKeyMonitorMvp.Services;

public sealed class UploadClient
{
    private readonly HttpClient _httpClient;

    public UploadClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<ClientUploadConfig> FetchClientConfigAsync(string baseUrl, string deviceId)
    {
        var url = new Uri(new Uri(NormalizeBaseUrl(baseUrl)), $"/api/v1/client-config?deviceId={Uri.EscapeDataString(deviceId)}");
        var response = await _httpClient.GetAsync(url);
        response.EnsureSuccessStatusCode();

        var config = await response.Content.ReadFromJsonAsync<ClientUploadConfig>(JsonOptions);
        return config ?? new ClientUploadConfig();
    }

    public async Task UploadSessionAsync(string baseUrl, SessionUploadPayload payload)
    {
        var url = new Uri(new Uri(NormalizeBaseUrl(baseUrl)), "/api/v1/ingest/session");
        var response = await _httpClient.PostAsJsonAsync(url, payload, JsonOptions);
        response.EnsureSuccessStatusCode();
    }

    private static JsonSerializerOptions JsonOptions => new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private static string NormalizeBaseUrl(string baseUrl)
    {
        var trimmed = (baseUrl ?? string.Empty).Trim();
        if (trimmed.EndsWith("/", StringComparison.Ordinal))
        {
            return trimmed[..^1];
        }
        return trimmed;
    }
}
