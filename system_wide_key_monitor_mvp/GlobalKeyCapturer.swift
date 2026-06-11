import Foundation
import AppKit

/// Global key capture using a Quartz event tap.
/// Implementation requires proper macOS permissions/entitlements (Accessibility).
final class GlobalKeyCapturer {

    enum CaptureError: LocalizedError {
        case alreadyStarted
        case eventTapCreationFailed
        case runLoopSourceCreationFailed

        var errorDescription: String? {
            switch self {
            case .alreadyStarted:
                return "Capture is already running."
            case .eventTapCreationFailed:
                return "Unable to create global event tap. Confirm Accessibility permission and relaunch the app if needed."
            case .runLoopSourceCreationFailed:
                return "Unable to create event run loop source."
            }
        }
    }

    typealias Handler = (KeyEventMetadata) -> Void

    private var eventTap: CFMachPort? = nil
    private var runLoopSource: CFRunLoopSource? = nil

    private let handler: Handler
    private let activeWindowInfo = ActiveWindowInfo()

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func start() throws {
        guard eventTap == nil else {
            throw CaptureError.alreadyStarted
        }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, cgEvent, refcon in
            let mySelf = Unmanaged<GlobalKeyCapturer>.fromOpaque(refcon!).takeUnretainedValue()
            mySelf.handle(eventType: type, cgEvent: cgEvent)
            return Unmanaged.passUnretained(cgEvent)
        }

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: selfPtr
        )

        guard let eventTap else {
            throw CaptureError.eventTapCreationFailed
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource else {
            self.eventTap = nil
            throw CaptureError.runLoopSourceCreationFailed
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(eventType: CGEventType, cgEvent: CGEvent) {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        guard eventType == .keyDown || eventType == .flagsChanged else { return }

        let flags = cgEvent.flags
        let modifiers = KeyEventMetadata.Modifiers(
            command: flags.contains(.maskCommand),
            shift: flags.contains(.maskShift),
            option: flags.contains(.maskAlternate),
            control: flags.contains(.maskControl),
            capsLock: nil
        )

        let keyCode = UInt16(cgEvent.getIntegerValueField(.keyboardEventKeycode))

        let keyIdentifier = String(describing: keyCode)

        let front = activeWindowInfo.frontmostAppNameAndBundleID()
        let title = activeWindowInfo.frontmostWindowTitle()

        let ev = KeyEventMetadata(
            ts: Date().timeIntervalSince1970,
            keyCode: keyCode,
            keyChar: nil,
            keyIdentifier: keyIdentifier,
            modifiers: modifiers,
            activeAppBundleID: front.bundleID,
            activeAppName: front.name,
            activeWindowTitle: title
        )

        handler(ev)
    }
}

private extension CGEventFlags {
    func contains(_ flag: CGEventFlags) -> Bool {
        return (self.rawValue & flag.rawValue) != 0
    }
}

