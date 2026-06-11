import Foundation
import AppKit
import ApplicationServices

/// Best-effort active window title fetch using Accessibility (AX).
///
/// MVP goal:
/// - Only retrieve window title metadata (no typed content).
/// - Works when the app has Accessibility trust.
final class AXWindowTitle {

    static func frontmostWindowTitle() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier

        let systemWide = AXUIElementCreateSystemWide()
        // We'll try to locate the focused element and read AXTitle.
        // AX APIs vary per app; this is intentionally best-effort.

        // 1) Try: focused window
        let focusedWindow = copyAttribute(systemWide, kAXFocusedWindowAttribute as CFString)
        if let focusedWindow = focusedWindow,
           let windowElement = asAXUIElement(focusedWindow),
           let title = copyStringAttribute(windowElement, kAXTitleAttribute as CFString) {
                return title
        }

        // 2) Try: focused UI element within app
        let appElement = AXUIElementCreateApplication(pid)
        let focusedUI = copyAttribute(appElement, kAXFocusedUIElementAttribute as CFString)
        if let focusedUI = focusedUI,
           let focusedElement = asAXUIElement(focusedUI),
           let title = copyStringAttribute(focusedElement, kAXTitleAttribute as CFString) {
                return title
        }

        return nil
    }

    private static func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        // Helper to query AXUIElement attributes.
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard err == .success else { return nil }
        return value
    }

    private static func copyStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        guard let value = copyAttribute(element, attribute), CFGetTypeID(value) == CFStringGetTypeID() else {
            return nil
        }
        return value as? String
    }

    private static func asAXUIElement(_ value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
}

