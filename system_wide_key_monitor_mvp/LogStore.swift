import Foundation

public final class LogStore: ObservableObject {
    @Published public private(set) var events: [KeyEventMetadata] = []

    private let retentionWindowSeconds: TimeInterval = 7 * 24 * 60 * 60
    private let database: EventDatabase
    private let maxInMemoryEvents: Int

    public init(maxInMemoryEvents: Int = 5_000) {
        self.maxInMemoryEvents = max(500, maxInMemoryEvents)
        do {
            self.database = try EventDatabase()
            try pruneExpiredEvents()
            self.events = try database.fetchRecent(limit: self.maxInMemoryEvents)
        } catch {
            fatalError("Unable to initialize local event database: \(error.localizedDescription)")
        }
    }

    public var persistentStoreURL: URL {
        database.fileURL
    }

    public var totalStoredEventCount: Int {
        (try? database.count()) ?? events.count
    }

    public var earliestStoredTimestamp: TimeInterval? {
        try? database.earliestTimestamp()
    }

    public func clear() {
        do {
            try database.clear()
            events.removeAll(keepingCapacity: false)
        } catch {
            // Keep in-memory data if disk clear fails.
        }
    }

    public func append(_ ev: KeyEventMetadata) {
        do {
            try pruneExpiredEvents()
        } catch {
            // Continue capture even if retention cleanup fails.
        }

        events.append(ev)
        if events.count > maxInMemoryEvents {
            events.removeFirst(events.count - maxInMemoryEvents)
        }

        do {
            try database.insert(ev)
        } catch {
            // In-memory capture remains available even if persistence fails.
        }
    }

    private func pruneExpiredEvents() throws {
        let cutoff = Date().timeIntervalSince1970 - retentionWindowSeconds
        try database.deleteEvents(olderThan: cutoff)
    }

    public func exportJSON(to url: URL, sessionStart: TimeInterval, sessionStop: TimeInterval?) throws {
        let persistedEvents = try database.fetchAll()
        let payload = CaptureSession(startedAt: sessionStart, stoppedAt: sessionStop, events: persistedEvents)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(payload)
        try data.write(to: url, options: [.atomic])
    }

    public func fetchAllPersistedEvents() -> [KeyEventMetadata] {
        (try? database.fetchAll()) ?? events
    }
}

