import Foundation

@MainActor
public final class OperationEngine {
    private let desktop: any DesktopSystem
    private let overlays: any OverlaySystem
    private let focusSelector: DirectionalFocusSelector
    private var activeCycle: CycleAction?
    private var nextCycleIndex = 0

    public init(
        desktop: any DesktopSystem,
        overlays: any OverlaySystem,
        focusSelector: DirectionalFocusSelector = DirectionalFocusSelector()
    ) {
        self.desktop = desktop
        self.overlays = overlays
        self.focusSelector = focusSelector
    }

    public func execute(_ action: Action) throws {
        switch action {
        case let .move(move):
            resetCycle()
            try execute(move)
        case let .cycle(cycle):
            try execute(cycle)
        case let .nudge(nudge):
            resetCycle()
            try execute(nudge)
        case let .focus(direction):
            resetCycle()
            try focus(direction)
        case .hints:
            resetCycle()
            try overlays.showHints(for: desktop.windows())
        case .grid:
            resetCycle()
            let window = try desktop.focusedWindow()
            let screen = try resolveScreen(.current, for: window, screens: desktop.screens())
            try overlays.showGrid(for: window, on: screen)
        }
    }

    private func execute(_ action: MoveAction) throws {
        let window = try desktop.focusedWindow()
        let screen = try resolveScreen(action.screen, for: window, screens: desktop.screens())
        let frame = try action.region.resolve(in: screen.visibleFrame, padding: action.padding)
        try desktop.setFrame(frame, of: window.id)
    }

    private func execute(_ action: CycleAction) throws {
        guard !action.placements.isEmpty else { throw OperationError.emptyCycle }
        let index = activeCycle == action ? nextCycleIndex : 0
        try execute(action.placements[index])
        activeCycle = action
        nextCycleIndex = (index + 1) % action.placements.count
    }

    private func resetCycle() {
        activeCycle = nil
        nextCycleIndex = 0
    }

    private func execute(_ action: NudgeAction) throws {
        let window = try desktop.focusedWindow()
        let screen = try resolveScreen(.current, for: window, screens: desktop.screens())
        let frame = Rect(
            x: window.frame.origin.x + screen.visibleFrame.size.width * action.x,
            y: window.frame.origin.y + screen.visibleFrame.size.height * action.y,
            width: window.frame.size.width,
            height: window.frame.size.height
        )
        try desktop.setFrame(frame, of: window.id)
    }

    private func focus(_ direction: Direction) throws {
        let source = try desktop.focusedWindow()
        guard let target = focusSelector.select(
            from: source,
            direction: direction,
            candidates: try desktop.windows()
        ) else {
            throw OperationError.noWindowInDirection(direction)
        }
        try desktop.focus(target.id)
    }

    private func resolveScreen(
        _ target: ScreenTarget,
        for window: WindowInfo,
        screens: [ScreenInfo]
    ) throws -> ScreenInfo {
        guard !screens.isEmpty else { throw OperationError.noScreens }
        let ordered = screens.sorted {
            if $0.frame.minX == $1.frame.minX {
                return $0.frame.minY < $1.frame.minY
            }
            return $0.frame.minX < $1.frame.minX
        }
        let current = ordered.max {
            $0.frame.intersectionArea(with: window.frame) < $1.frame.intersectionArea(with: window.frame)
        } ?? ordered[0]

        switch target {
        case .current:
            return current
        case .main:
            return screens.first(where: \.isMain) ?? screens[0]
        case .next, .previous:
            guard let index = ordered.firstIndex(where: { $0.id == current.id }) else {
                return current
            }
            let offset = target == .next ? 1 : -1
            return ordered[(index + offset + ordered.count) % ordered.count]
        }
    }
}

public enum OperationError: LocalizedError, Equatable, Sendable {
    case noScreens
    case emptyCycle
    case noWindowInDirection(Direction)

    public var errorDescription: String? {
        switch self {
        case .noScreens:
            "No screens are available."
        case .emptyCycle:
            "A cycle action has no placements."
        case let .noWindowInDirection(direction):
            "No visible window was found to the \(direction.rawValue)."
        }
    }
}
