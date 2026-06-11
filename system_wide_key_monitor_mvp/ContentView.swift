import SwiftUI

struct ContentView: View {
    @StateObject private var logStore = LogStore()

    @State private var isCapturing: Bool = false
    @State private var statusText: String = "Capture is OFF."

    @State private var sessionStart: TimeInterval? = nil
    @State private var sessionStop: TimeInterval? = nil
    @State private var sessionID: String? = nil

    @State private var backendBaseURL: String = UserDefaults.standard.string(forKey: "keyMonitor.backendBaseURL") ?? "http://localhost:8787"
    @State private var uploadEnabledByServer: Bool = true
    @State private var uploadIntervalSeconds: Int = 120
    @State private var uploadTimer: Timer? = nil
    @State private var lastUploadStatus: String = "Auto-upload idle."
    private let uploadClient = UploadClient()
    private let deviceID = DeviceIdentity.currentDeviceID()

    @State private var capturer: GlobalKeyCapturer? = nil
    private let permissionManager = PermissionManager()


    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System-wide Key Monitor")
                .font(.title2)
                .bold()

            Text("Metadata-only capture: key identity/code + modifier state + active window/app title. Typed text is not captured.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Stored locally in SQLite: \(logStore.totalStoredEventCount) event(s)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Central backend")
                    .font(.footnote)
                    .bold()
                TextField("http://localhost:8787", text: $backendBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: backendBaseURL) { newValue in
                        UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "keyMonitor.backendBaseURL")
                    }
                Text("Auto-upload: \(uploadEnabledByServer ? "enabled" : "disabled") | Interval: \(uploadIntervalSeconds)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(lastUploadStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 12) {
                Toggle(isOn: $isCapturing) {
                    Text("Capture")
                }
                .onChange(of: isCapturing) { newValue in
                    if newValue {
                        startCapture()
                    } else {
                        stopCapture()
                    }
                }
            }

            Text(statusText)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 12) {
                Button("Clear log") {
                    logStore.clear()
                    sessionStart = nil
                    sessionStop = nil
                    statusText = "Local log cleared."
                }
                .disabled(logStore.events.isEmpty)

                Button("Export JSON") {
                    exportJSON()
                }
                .disabled(logStore.events.isEmpty)
            }

            Divider()

            Text("Recent events (in memory): \(min(logStore.events.count, 50)) shown")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    let recent = Array(logStore.events.suffix(50))
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, ev in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatTime(ev.ts))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(verbatim: "keyIdentifier: \(ev.keyIdentifier) code: \(ev.keyCode) mods: cmd=\(ev.modifiers.command) shift=\(ev.modifiers.shift) opt=\(ev.modifiers.option) ctrl=\(ev.modifiers.control)")
                                .font(.system(.body, design: .monospaced))

                            if let app = ev.activeAppName {
                                Text("app: \(app) | window: \(ev.activeWindowTitle ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            isCapturing = false
            if logStore.totalStoredEventCount > 0 {
                statusText = "Capture is OFF. Loaded \(logStore.totalStoredEventCount) persisted event(s)."
            } else {
                statusText = "Capture is OFF."
            }
        }
        .onDisappear {
            stopAutoUploadLoop()
            if isCapturing {
                stopCapture()
            }
        }
    }

    private func startCapture() {
        // Permission gating
        if !permissionManager.isAccessibilityTrusted() {
            statusText = "Requesting Accessibility permission..."
            _ = permissionManager.requestAccessibilityPermissionAndWait()

            // Re-check immediately; user may need to accept in System Settings.
            if !permissionManager.isAccessibilityTrusted() {
                statusText = "Accessibility permission not granted. Capture is OFF."
                isCapturing = false
                return
            }
        }

        // Start capturer
        if sessionStart == nil {
            sessionStart = Date().timeIntervalSince1970
        }
        if sessionID == nil {
            sessionID = UUID().uuidString
        }
        sessionStop = nil

        let newCapturer = GlobalKeyCapturer { ev in
            logStore.append(ev)
        }
        do {
            try newCapturer.start()
            capturer = newCapturer
        } catch {
            statusText = "Capture failed to start: \(error.localizedDescription)"
            isCapturing = false
            return
        }

        statusText = "Capture is ON (metadata-only, global)."
        isCapturing = true
        startAutoUploadLoop()
    }

    private func stopCapture() {
        sessionStop = Date().timeIntervalSince1970
        capturer?.stop()
        capturer = nil
        statusText = "Capture is OFF."
        isCapturing = false
        stopAutoUploadLoop()
    }


    private func exportJSON() {
        guard logStore.totalStoredEventCount > 0 else {
            statusText = "No stored events to export."
            return
        }

        let effectiveSessionStart = sessionStart ?? logStore.earliestStoredTimestamp ?? Date().timeIntervalSince1970

        let sessionStopVal = sessionStop

        FileExport.exportJSONViaSavePanel { url in
            try logStore.exportJSON(to: url, sessionStart: effectiveSessionStart, sessionStop: sessionStopVal)
        }

        statusText = "Export complete."
    }




    private func formatTime(_ ts: TimeInterval) -> String {
        let d = Date(timeIntervalSince1970: ts)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: d)
    }

    private func startAutoUploadLoop() {
        stopAutoUploadLoop()
        Task {
            await refreshClientConfigAndReschedule()
            await performAutoUpload()
        }
    }

    private func stopAutoUploadLoop() {
        uploadTimer?.invalidate()
        uploadTimer = nil
    }

    @MainActor
    private func scheduleUploadTimer(intervalSeconds: Int) {
        uploadTimer?.invalidate()
        uploadTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(max(30, intervalSeconds)), repeats: true) { _ in
            Task {
                await refreshClientConfigAndReschedule()
                await performAutoUpload()
            }
        }
    }

    private func normalizedBackendURL() -> String {
        let trimmed = backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") {
            return String(trimmed.dropLast())
        }
        return trimmed
    }

    @MainActor
    private func refreshClientConfigAndReschedule() async {
        do {
            let config = try await uploadClient.fetchClientConfig(baseURL: normalizedBackendURL(), deviceId: deviceID)
            let nextInterval = max(30, config.uploadIntervalSeconds)
            let didIntervalChange = nextInterval != uploadIntervalSeconds
            uploadEnabledByServer = config.uploadEnabled
            uploadIntervalSeconds = nextInterval

            if uploadTimer == nil || didIntervalChange {
                scheduleUploadTimer(intervalSeconds: nextInterval)
            }
        } catch {
            lastUploadStatus = "Config fetch failed: \(error.localizedDescription)"
            if uploadTimer == nil {
                scheduleUploadTimer(intervalSeconds: uploadIntervalSeconds)
            }
        }
    }

    @MainActor
    private func performAutoUpload() async {
        guard uploadEnabledByServer else {
            lastUploadStatus = "Auto-upload disabled by backend."
            return
        }

        guard let startedAt = sessionStart, let currentSessionID = sessionID else {
            lastUploadStatus = "No active session to upload."
            return
        }

        let persistedEvents = logStore.fetchAllPersistedEvents().filter { $0.ts >= startedAt }

        guard !persistedEvents.isEmpty else {
            lastUploadStatus = "No events yet for this session."
            return
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let payload = UploadSessionPayload(
            deviceId: deviceID,
            platform: "macos",
            appVersion: appVersion,
            source: "system_wide_key_monitor_mvp",
            sessionId: currentSessionID,
            startedAt: startedAt,
            stoppedAt: sessionStop,
            events: persistedEvents
        )

        do {
            try await uploadClient.uploadSession(baseURL: normalizedBackendURL(), payload: payload)
            lastUploadStatus = "Uploaded \(persistedEvents.count) event(s) at \(formatTime(Date().timeIntervalSince1970))."
        } catch {
            lastUploadStatus = "Upload failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}

