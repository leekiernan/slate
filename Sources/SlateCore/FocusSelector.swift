import Foundation

public struct DirectionalFocusSelector: Sendable {
    public init() {}

    public func select(
        from source: WindowInfo,
        direction: Direction,
        candidates: [WindowInfo]
    ) -> WindowInfo? {
        candidates
            .filter { $0.id != source.id && $0.isVisible }
            .compactMap { candidate -> (WindowInfo, Double)? in
                let dx = candidate.frame.midX - source.frame.midX
                let dy = candidate.frame.midY - source.frame.midY
                let distances = directionalDistances(dx: dx, dy: dy, direction: direction)
                guard distances.forward > 0 else { return nil }

                // Prefer nearby windows while penalizing candidates far off the travel axis.
                let score = distances.forward + distances.cross * 1.5
                return (candidate, score)
            }
            .min {
                if $0.1 == $1.1 {
                    return $0.0.id.rawValue < $1.0.id.rawValue
                }
                return $0.1 < $1.1
            }?
            .0
    }

    private func directionalDistances(
        dx: Double,
        dy: Double,
        direction: Direction
    ) -> (forward: Double, cross: Double) {
        switch direction {
        case .left:
            (-dx, abs(dy))
        case .right:
            (dx, abs(dy))
        case .up:
            (-dy, abs(dx))
        case .down:
            (dy, abs(dx))
        }
    }
}
