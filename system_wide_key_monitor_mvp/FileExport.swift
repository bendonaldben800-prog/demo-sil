import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum FileExport {

    @MainActor
    static func exportJSONViaSavePanel(
        makeFilename: () -> String = {
            let ts = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            return "key-events-\(ts).json"
        },
        payloadWriter: (URL) throws -> Void
    ) {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = makeFilename()
        panel.title = "Export key events JSON"

        let response = panel.runModal()
        if response == .OK {
            let url = panel.url!
            do {
                try payloadWriter(url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        #else
        throw NSError(domain: "FileExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported platform"])
        #endif
    }
}

