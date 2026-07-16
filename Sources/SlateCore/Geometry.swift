import Foundation

public struct Point: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Size: Codable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct Rect: Codable, Hashable, Sendable {
    public var origin: Point
    public var size: Size

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }

    public func intersectionArea(with other: Rect) -> Double {
        let width = max(0, min(maxX, other.maxX) - max(minX, other.minX))
        let height = max(0, min(maxY, other.maxY) - max(minY, other.minY))
        return width * height
    }
}

public struct NormalizedRect: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func resolve(in bounds: Rect, padding: Double = 0) throws -> Rect {
        let result = Rect(
            x: bounds.minX + bounds.size.width * x + padding,
            y: bounds.minY + bounds.size.height * y + padding,
            width: bounds.size.width * width - padding * 2,
            height: bounds.size.height * height - padding * 2
        )
        guard result.size.width > 0, result.size.height > 0 else {
            throw GeometryError.paddingConsumesRegion
        }
        return result
    }
}

public enum GeometryError: Error, Equatable, Sendable {
    case paddingConsumesRegion
}
