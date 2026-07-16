import Foundation

public struct WindowID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct WindowInfo: Hashable, Sendable {
    public let id: WindowID
    public let processIdentifier: Int32
    public let applicationName: String
    public let title: String
    public let frame: Rect
    public let isFocused: Bool
    public let isVisible: Bool

    public init(
        id: WindowID,
        processIdentifier: Int32,
        applicationName: String,
        title: String,
        frame: Rect,
        isFocused: Bool = false,
        isVisible: Bool = true
    ) {
        self.id = id
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.title = title
        self.frame = frame
        self.isFocused = isFocused
        self.isVisible = isVisible
    }
}

public struct ScreenInfo: Hashable, Sendable {
    public let id: String
    public let frame: Rect
    public let visibleFrame: Rect
    public let isMain: Bool

    public init(id: String, frame: Rect, visibleFrame: Rect, isMain: Bool = false) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.isMain = isMain
    }
}

@MainActor
public protocol DesktopSystem: AnyObject {
    func screens() throws -> [ScreenInfo]
    func windows() throws -> [WindowInfo]
    func focusedWindow() throws -> WindowInfo
    func setFrame(_ frame: Rect, of window: WindowID) throws
    func focus(_ window: WindowID) throws
}

@MainActor
public protocol OverlaySystem: AnyObject {
    func showHints(for windows: [WindowInfo]) throws
    func showGrid(for window: WindowInfo, on screen: ScreenInfo) throws
}
