import Foundation
import AppKit

/// Permission gating for global event taps.
/// On macOS, global input monitoring typically requires Accessibility permission.
///
/// In this MVP, we do a best-effort check using AXUIElement on the current app.
/// Implementing a fully correct AX permission check requires importing
/// ApplicationServices and checking kAXTrustedCheckOptionPrompt / AXIsProcessTrusted.
///
/// For scaffolding, this manager provides a simple API that triggers the prompt.
final class PermissionManager {

    func requestAccessibilityPermissionAndWait() -> Bool {
        // Trigger Accessibility prompt
        let options: [String: Any] = ["AXTrustedCheckOptionPrompt": true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        // AXIsProcessTrustedWithOptions returns immediately; permission may be granted slightly later.
        // MVP: we return the immediate value; UI should allow user to toggle again if needed.
        return isTrusted
    }

    func isAccessibilityTrusted() -> Bool {
        return AXIsProcessTrusted()
    }
}




