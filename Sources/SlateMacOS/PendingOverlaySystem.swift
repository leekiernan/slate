import Foundation
import SlateCore

@MainActor
public final class PendingOverlaySystem: OverlaySystem {
    public init() {}

    public func showHints(for windows: [WindowInfo]) throws {
        throw OverlayError.notImplemented("Window hints")
    }

    public func showGrid(for window: WindowInfo, on screen: ScreenInfo) throws {
        throw OverlayError.notImplemented("Grid selection")
    }
}

public enum OverlayError: LocalizedError {
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case let .notImplemented(feature):
            "\(feature) is part of the v1 scope but is not implemented in this first vertical slice."
        }
    }
}
