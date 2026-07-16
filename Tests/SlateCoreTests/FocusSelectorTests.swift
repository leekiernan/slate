import SlateCore
import Testing

@Test
func selectsNearestWindowInRequestedDirection() {
    let source = window("source", x: 100, y: 100)
    let closeRight = window("close", x: 350, y: 110)
    let farRight = window("far", x: 700, y: 100)
    let diagonal = window("diagonal", x: 300, y: 500)

    let selected = DirectionalFocusSelector().select(
        from: source,
        direction: .right,
        candidates: [farRight, diagonal, closeRight, source]
    )

    #expect(selected?.id == closeRight.id)
}

@Test
func ignoresHiddenAndWrongDirectionWindows() {
    let source = window("source", x: 100, y: 100)
    let hidden = window("hidden", x: 300, y: 100, isVisible: false)
    let left = window("left", x: 0, y: 100)

    let selected = DirectionalFocusSelector().select(
        from: source,
        direction: .right,
        candidates: [hidden, left]
    )

    #expect(selected == nil)
}

private func window(_ id: String, x: Double, y: Double, isVisible: Bool = true) -> WindowInfo {
    WindowInfo(
        id: WindowID(rawValue: id),
        processIdentifier: 1,
        applicationName: "Test",
        title: id,
        frame: Rect(x: x, y: y, width: 100, height: 100),
        isVisible: isVisible
    )
}
