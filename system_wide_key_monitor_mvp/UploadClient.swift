import Foundation

@MainActor
final class UploadClient {
    enum UploadError: LocalizedError {
        case invalidURL
        case httpError(code: Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid backend URL."
            case let .httpError(code):
                return "Upload failed with HTTP status \(code)."
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchClientConfig(baseURL: String, deviceId: String) async throws -> ClientUploadConfig {
        guard var components = URLComponents(string: baseURL) else {
            throw UploadError.invalidURL
        }

        components.path = "/api/v1/client-config"
        components.queryItems = [URLQueryItem(name: "deviceId", value: deviceId)]

        guard let url = components.url else {
            throw UploadError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 15

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw UploadError.httpError(code: -1)
        }
        guard 200..<300 ~= http.statusCode else {
            throw UploadError.httpError(code: http.statusCode)
        }

        return try JSONDecoder().decode(ClientUploadConfig.self, from: data)
    }

    func uploadSession(baseURL: String, payload: UploadSessionPayload) async throws {
        guard let url = URL(string: "/api/v1/ingest/session", relativeTo: URL(string: baseURL)) else {
            throw UploadError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw UploadError.httpError(code: -1)
        }
        guard 200..<300 ~= http.statusCode else {
            throw UploadError.httpError(code: http.statusCode)
        }
    }
}

enum DeviceIdentity {
    static func currentDeviceID() -> String {
        let defaults = UserDefaults.standard
        let key = "keyMonitor.deviceId"
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }

        let hostName = Host.current().localizedName ?? "mac"
        let newValue = "\(hostName)-\(UUID().uuidString)"
        defaults.set(newValue, forKey: key)
        return newValue
    }
}
