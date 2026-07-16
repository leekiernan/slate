import SlateCore
import Testing

@MainActor
@Test
func moveActionUsesCurrentScreenVisibleFrame() throws {
    let focused = WindowInfo(
        id: WindowID(rawValue: "focused"),
        processIdentifier: 1,
        applicationName: "Test",
        title: "Focused",
        frame: Rect(x: 100, y: 100, width: 300, height: 200),
        isFocused: true
    )
    let desktop = DesktopStub(
        screenValues: [
            ScreenInfo(
                id: "main",
                frame: Rect(x: 0, y: 0, width: 1_000, height: 900),
                visibleFrame: Rect(x: 0, y: 25, width: 1_000, height: 875),
                isMain: true
            )
        ],
        windowValues: [focused],
        focused: focused
    )
    let engine = OperationEngine(desktop: desktop, overlays: OverlayStub())

    try engine.execute(.move(MoveAction(
        region: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1),
        padding: 10
    )))

    #expect(desktop.lastFrame == Rect(x: 510, y: 35, width: 480, height: 855))
    #expect(desktop.lastWindow == focused.id)
}

@MainActor
@Test
func cycleActionAdvancesThroughPlacementsAndWraps() throws {
    let focused = WindowInfo(
        id: WindowID(rawValue: "focused"),
        processIdentifier: 1,
        applicationName: "Test",
        title: "Focused",
        frame: Rect(x: 100, y: 100, width: 300, height: 200),
        isFocused: true
    )
    let desktop = DesktopStub(
        screenValues: [ScreenInfo(
            id: "main",
            frame: Rect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: Rect(x: 0, y: 0, width: 1_000, height: 800),
            isMain: true
        )],
        windowValues: [focused],
        focused: focused
    )
    let engine = OperationEngine(desktop: desktop, overlays: OverlayStub())
    let action = Action.cycle(CycleAction(placements: [
        MoveAction(region: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1)),
        MoveAction(region: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.5)),
        MoveAction(region: NormalizedRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    ]))

    try engine.execute(action)
    try engine.execute(action)
    try engine.execute(action)
    try engine.execute(action)

    #expect(desktop.frames == [
        Rect(x: 500, y: 0, width: 500, height: 800),
        Rect(x: 500, y: 0, width: 500, height: 400),
        Rect(x: 500, y: 400, width: 500, height: 400),
        Rect(x: 500, y: 0, width: 500, height: 800)
    ])
}

@MainActor
@Test
func switchingCycleActionsRestartsAtFirstPlacement() throws {
    let focused = WindowInfo(
        id: WindowID(rawValue: "focused"),
        processIdentifier: 1,
        applicationName: "Test",
        title: "Focused",
        frame: Rect(x: 100, y: 100, width: 300, height: 200),
        isFocused: true
    )
    let desktop = DesktopStub(
        screenValues: [ScreenInfo(
            id: "main",
            frame: Rect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: Rect(x: 0, y: 0, width: 1_000, height: 800),
            isMain: true
        )],
        windowValues: [focused],
        focused: focused
    )
    let engine = OperationEngine(desktop: desktop, overlays: OverlayStub())
    let right = Action.cycle(CycleAction(placements: [
        MoveAction(region: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1)),
        MoveAction(region: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
    ]))
    let left = Action.cycle(CycleAction(placements: [
        MoveAction(region: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1)),
        MoveAction(region: NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5))
    ]))

    try engine.execute(right)
    try engine.execute(right)
    try engine.execute(left)
    try engine.execute(right)

    #expect(desktop.frames == [
        Rect(x: 500, y: 0, width: 500, height: 800),
        Rect(x: 500, y: 0, width: 500, height: 400),
        Rect(x: 0, y: 0, width: 500, height: 800),
        Rect(x: 500, y: 0, width: 500, height: 800)
    ])
}

@MainActor
@Test
func nudgeActionMovesWithoutResizing() throws {
    let focused = WindowInfo(
        id: WindowID(rawValue: "focused"),
        processIdentifier: 1,
        applicationName: "Test",
        title: "Focused",
        frame: Rect(x: 100, y: 150, width: 300, height: 200),
        isFocused: true
    )
    let desktop = DesktopStub(
        screenValues: [ScreenInfo(
            id: "main",
            frame: Rect(x: 0, y: 0, width: 1_000, height: 900),
            visibleFrame: Rect(x: 0, y: 25, width: 1_000, height: 800),
            isMain: true
        )],
        windowValues: [focused],
        focused: focused
    )
    let engine = OperationEngine(desktop: desktop, overlays: OverlayStub())

    try engine.execute(.nudge(NudgeAction(x: 0.125, y: -0.125)))

    #expect(desktop.lastFrame == Rect(x: 225, y: 50, width: 300, height: 200))
    #expect(desktop.lastWindow == focused.id)
}

@MainActor
@Test
func focusActionUsesDirectionalSelection() throws {
    let focused = makeWindow("focused", x: 100)
    let right = makeWindow("right", x: 500)
    let desktop = DesktopStub(
        screenValues: [ScreenInfo(
            id: "main",
            frame: Rect(x: 0, y: 0, width: 1_000, height: 900),
            visibleFrame: Rect(x: 0, y: 0, width: 1_000, height: 900),
            isMain: true
        )],
        windowValues: [focused, right],
        focused: focused
    )
    let engine = OperationEngine(desktop: desktop, overlays: OverlayStub())

    try engine.execute(.focus(.right))

    #expect(desktop.lastWindow == right.id)
}

private func makeWindow(_ id: String, x: Double) -> WindowInfo {
    WindowInfo(
        id: WindowID(rawValue: id),
        processIdentifier: 1,
        applicationName: "Test",
        title: id,
        frame: Rect(x: x, y: 100, width: 200, height: 200)
    )
}

@MainActor
private final class DesktopStub: DesktopSystem {
    let screenValues: [ScreenInfo]
    let windowValues: [WindowInfo]
    let focused: WindowInfo
    var lastFrame: Rect?
    var frames: [Rect] = []
    var lastWindow: WindowID?

    init(screenValues: [ScreenInfo], windowValues: [WindowInfo], focused: WindowInfo) {
        self.screenValues = screenValues
        self.windowValues = windowValues
        self.focused = focused
    }

    func screens() throws -> [ScreenInfo] { screenValues }
    func windows() throws -> [WindowInfo] { windowValues }
    func focusedWindow() throws -> WindowInfo { focused }

    func setFrame(_ frame: Rect, of window: WindowID) throws {
        lastFrame = frame
        frames.append(frame)
        lastWindow = window
    }

    func focus(_ window: WindowID) throws {
        lastWindow = window
    }
}

@MainActor
private final class OverlayStub: OverlaySystem {
    func showHints(for windows: [WindowInfo]) throws {}
    func showGrid(for window: WindowInfo, on screen: ScreenInfo) throws {}
}
