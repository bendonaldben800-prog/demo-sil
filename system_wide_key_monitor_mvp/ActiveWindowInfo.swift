import Foundation
import AppKit

/// Best-effort retrieval of frontmost app/window metadata.
/// Note: Exact window title availability depends on accessibility + app.
final class ActiveWindowInfo {

    func frontmostAppNameAndBundleID() -> (name: String?, bundleID: String?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil)
        }
        return (app.localizedName, app.bundleIdentifier)
    }

    func frontmostWindowTitle() -> String? {
        // Best-effort using Accessibility (AX).
        // Requires Accessibility trust (PermissionManager must have granted it).
        return AXWindowTitle.frontmostWindowTitle()
    }

}

