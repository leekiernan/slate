import SlateCore
import Testing

@Test
func resolvesNormalizedRegionWithPadding() throws {
    let region = NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1)

    let result = try region.resolve(
        in: Rect(x: 0, y: 20, width: 1200, height: 780),
        padding: 10
    )

    #expect(result == Rect(x: 610, y: 30, width: 580, height: 760))
}

@Test
func calculatesIntersectionArea() {
    let first = Rect(x: 0, y: 0, width: 100, height: 100)
    let second = Rect(x: 50, y: 25, width: 100, height: 100)

    #expect(first.intersectionArea(with: second) == 3_750)
}
