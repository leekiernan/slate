import AppKit
import ApplicationServices
import SlateCore

@MainActor
public final class AccessibilityDesktop: DesktopSystem {
    private var elements: [WindowID: AXUIElement] = [:]

    public init() {}

    public func screens() throws -> [ScreenInfo] {
        let screens = NSScreen.screens
        guard let reference = screens.first else { return [] }
        let referenceTop = reference.frame.maxY

        return screens.enumerated().map { index, screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                .map(String.init(describing:)) ?? String(index)
            return ScreenInfo(
                id: number,
                frame: Self.accessibilityRect(from: screen.frame, referenceTop: referenceTop),
                visibleFrame: Self.accessibilityRect(from: screen.visibleFrame, referenceTop: referenceTop),
                isMain: index == 0
            )
        }
    }

    public func windows() throws -> [WindowInfo] {
        elements.removeAll(keepingCapacity: true)
        let focused = try? focusedElement()
        var result: [WindowInfo] = []

        for application in NSWorkspace.shared.runningApplications
        where application.activationPolicy == .regular && application.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
            guard let windowElements = try? elementArrayAttribute(applicationElement, kAXWindowsAttribute as CFString) else {
                continue
            }
            for element in windowElements {
                guard let info = try? makeWindowInfo(
                    element,
                    applicationName: application.localizedName ?? application.bundleIdentifier ?? "Unknown",
                    isFocused: focused.map { CFEqual($0, element) } ?? false
                ) else {
                    continue
                }
                result.append(info)
            }
        }
        return result
    }

    public func focusedWindow() throws -> WindowInfo {
        let element = try focusedElement()
        var processIdentifier: pid_t = 0
        try check(AXUIElementGetPid(element, &processIdentifier), operation: "read focused window process")
        let application = NSRunningApplication(processIdentifier: processIdentifier)
        return try makeWindowInfo(
            element,
            applicationName: application?.localizedName ?? application?.bundleIdentifier ?? "Unknown",
            isFocused: true
        )
    }

    public func setFrame(_ frame: Rect, of window: WindowID) throws {
        let element = try element(for: window)
        var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        var size = CGSize(width: frame.size.width, height: frame.size.height)
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw AccessibilityError.cannotCreateValue
        }

        // A second size write handles applications that constrain the first resize while moving.
        try check(AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue), operation: "resize window")
        try check(AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue), operation: "move window")
        try check(AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue), operation: "resize window")
    }

    public func focus(_ window: WindowID) throws {
        let element = try element(for: window)
        var processIdentifier: pid_t = 0
        try check(AXUIElementGetPid(element, &processIdentifier), operation: "read window process")

        _ = AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        try check(AXUIElementPerformAction(element, kAXRaiseAction as CFString), operation: "raise window")
        NSRunningApplication(processIdentifier: processIdentifier)?.activate()
    }

    private func focusedElement() throws -> AXUIElement {
        let system = AXUIElementCreateSystemWide()
        let application: AXUIElement
        do {
            application = try elementAttribute(system, kAXFocusedApplicationAttribute as CFString)
        } catch let error as AccessibilityError {
            guard case let .operationFailed(_, code) = error,
                  code == AXError.noValue.rawValue,
                  let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
                throw error
            }

            // Chromium can transiently leave the system-wide focused-application
            // attribute empty even though AppKit still knows which app is frontmost.
            application = AXUIElementCreateApplication(frontmostApplication.processIdentifier)
        }
        return try elementAttribute(application, kAXFocusedWindowAttribute as CFString)
    }

    private func makeWindowInfo(
        _ element: AXUIElement,
        applicationName: String,
        isFocused: Bool
    ) throws -> WindowInfo {
        var processIdentifier: pid_t = 0
        try check(AXUIElementGetPid(element, &processIdentifier), operation: "read window process")

        let position = try pointAttribute(element, kAXPositionAttribute as CFString)
        let size = try sizeAttribute(element, kAXSizeAttribute as CFString)
        let title = (try? stringAttribute(element, kAXTitleAttribute as CFString)) ?? ""
        let minimized = (try? boolAttribute(element, kAXMinimizedAttribute as CFString)) ?? false
        let id = WindowID(rawValue: "\(processIdentifier):\(CFHash(element))")
        elements[id] = element

        return WindowInfo(
            id: id,
            processIdentifier: processIdentifier,
            applicationName: applicationName,
            title: title,
            frame: Rect(x: position.x, y: position.y, width: size.width, height: size.height),
            isFocused: isFocused,
            isVisible: !minimized
        )
    }

    private func element(for id: WindowID) throws -> AXUIElement {
        if let element = elements[id] {
            return element
        }
        _ = try focusedWindow()
        guard let element = elements[id] else {
            throw AccessibilityError.windowNoLongerAvailable
        }
        return element
    }

    private func attribute(_ element: AXUIElement, _ name: CFString) throws -> CFTypeRef {
        var value: CFTypeRef?
        try check(AXUIElementCopyAttributeValue(element, name, &value), operation: "read \(name)")
        guard let value else { throw AccessibilityError.missingAttribute(String(name)) }
        return value
    }

    private func elementAttribute(_ element: AXUIElement, _ name: CFString) throws -> AXUIElement {
        let value = try attribute(element, name)
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw AccessibilityError.invalidAttribute(String(name))
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func elementArrayAttribute(_ element: AXUIElement, _ name: CFString) throws -> [AXUIElement] {
        let value = try attribute(element, name)
        guard let values = value as? [AnyObject] else {
            throw AccessibilityError.invalidAttribute(String(name))
        }
        return values.compactMap { value in
            guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
            return unsafeDowncast(value, to: AXUIElement.self)
        }
    }

    private func pointAttribute(_ element: AXUIElement, _ name: CFString) throws -> CGPoint {
        let value = try attribute(element, name)
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            throw AccessibilityError.invalidAttribute(String(name))
        }
        var point = CGPoint.zero
        guard AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cgPoint, &point) else {
            throw AccessibilityError.invalidAttribute(String(name))
        }
        return point
    }

    private func sizeAttribute(_ element: AXUIElement, _ name: CFString) throws -> CGSize {
        let value = try attribute(element, name)
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            throw AccessibilityError.invalidAttribute(String(name))
        }
        var size = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cgSize, &size) else {
            throw AccessibilityError.invalidAttribute(String(name))
        }
        return size
    }

    private func stringAttribute(_ element: AXUIElement, _ name: CFString) throws -> String {
        guard let value = try attribute(element, name) as? String else {
            throw AccessibilityError.invalidAttribute(String(name))
        }
        return value
    }

    private func boolAttribute(_ element: AXUIElement, _ name: CFString) throws -> Bool {
        guard let value = try attribute(element, name) as? NSNumber else {
            throw AccessibilityError.invalidAttribute(String(name))
        }
        return value.boolValue
    }

    private func check(_ error: AXError, operation: String) throws {
        guard error == .success else {
            throw AccessibilityError.operationFailed(operation, error.rawValue)
        }
    }

    private static func accessibilityRect(from rect: NSRect, referenceTop: CGFloat) -> Rect {
        Rect(
            x: rect.minX,
            y: referenceTop - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

public enum AccessibilityError: LocalizedError {
    case cannotCreateValue
    case missingAttribute(String)
    case invalidAttribute(String)
    case operationFailed(String, Int32)
    case windowNoLongerAvailable

    public var errorDescription: String? {
        switch self {
        case .cannotCreateValue:
            "Could not create an Accessibility value."
        case let .missingAttribute(attribute):
            "Accessibility attribute \(attribute) is missing."
        case let .invalidAttribute(attribute):
            "Accessibility attribute \(attribute) has an unexpected type."
        case let .operationFailed(operation, code):
            "Could not \(operation) (AX error \(code))."
        case .windowNoLongerAvailable:
            "The selected window is no longer available."
        }
    }
}
