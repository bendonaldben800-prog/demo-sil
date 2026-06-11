using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using WindowsKeyMonitorMvp.Models;

namespace WindowsKeyMonitorMvp.Services;

public static class JsonExportService
{
    public static void Export(string outputPath, double startedAt, double? stoppedAt, List<KeyEventMetadata> events)
    {
        var payload = new
        {
            startedAt,
            stoppedAt,
            events
        };

        var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions
        {
            WriteIndented = true
        });

        File.WriteAllText(outputPath, json);
    }
}
