import Foundation

/// Metadata-only key event representation.
/// Typed character content is intentionally not captured.
public struct KeyEventMetadata: Codable, Hashable {
    public struct Modifiers: Codable, Hashable {
        public var command: Bool
        public var shift: Bool
        public var option: Bool
        public var control: Bool
        public var capsLock: Bool?

        public init(command: Bool, shift: Bool, option: Bool, control: Bool, capsLock: Bool? = nil) {
            self.command = command
            self.shift = shift
            self.option = option
            self.control = control
            self.capsLock = capsLock
        }
    }

    public var ts: TimeInterval
    public var keyCode: UInt16
    public var keyChar: String?
    public var keyIdentifier: String
    public var modifiers: Modifiers
    public var activeAppBundleID: String?
    public var activeAppName: String?
    public var activeWindowTitle: String?
}

public struct CaptureSession: Codable {
    public var startedAt: TimeInterval
    public var stoppedAt: TimeInterval?
    public var events: [KeyEventMetadata]
}

public struct UploadSessionPayload: Codable {
    public var deviceId: String
    public var platform: String
    public var appVersion: String
    public var source: String
    public var sessionId: String
    public var startedAt: TimeInterval
    public var stoppedAt: TimeInterval?
    public var events: [KeyEventMetadata]
}

public struct ClientUploadConfig: Codable {
    public var uploadEnabled: Bool
    public var uploadIntervalSeconds: Int
}

