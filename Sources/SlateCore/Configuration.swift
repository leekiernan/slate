import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public let version: Int
    public let bindings: [Binding]

    public init(version: Int = 1, bindings: [Binding]) {
        self.version = version
        self.bindings = bindings
    }

    public func validate() throws {
        guard version == 1 else {
            throw ConfigurationError.unsupportedVersion(version)
        }

        var chords = Set<String>()
        for binding in bindings {
            guard !binding.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ConfigurationError.emptyKey
            }
            guard Set(binding.modifiers).count == binding.modifiers.count else {
                throw ConfigurationError.duplicateModifier(binding.key)
            }

            let chord = ([binding.key.lowercased()] + binding.modifiers.map(\.rawValue).sorted())
                .joined(separator: "+")
            guard chords.insert(chord).inserted else {
                throw ConfigurationError.duplicateBinding(chord)
            }

            switch binding.action {
            case let .move(move):
                try move.validate()
            case let .cycle(cycle):
                try cycle.validate()
            case .nudge, .focus, .hints, .grid:
                break
            }
        }
    }
}

public struct Binding: Codable, Equatable, Sendable {
    public let key: String
    public let modifiers: [KeyModifier]
    public let action: Action

    public init(key: String, modifiers: [KeyModifier], action: Action) {
        self.key = key
        self.modifiers = modifiers
        self.action = action
    }
}

public enum KeyModifier: String, Codable, CaseIterable, Sendable {
    case command
    case control
    case option
    case shift
}

public enum Direction: String, Codable, Sendable {
    case left
    case right
    case up
    case down
}

public enum ScreenTarget: String, Codable, Hashable, Sendable {
    case current
    case main
    case next
    case previous
}

public struct MoveAction: Codable, Hashable, Sendable {
    public let region: NormalizedRect
    public let screen: ScreenTarget
    public let padding: Double

    public init(region: NormalizedRect, screen: ScreenTarget = .current, padding: Double = 0) {
        self.region = region
        self.screen = screen
        self.padding = padding
    }

    fileprivate func validate() throws {
        guard region.x >= 0, region.y >= 0,
              region.width > 0, region.height > 0,
              region.x + region.width <= 1,
              region.y + region.height <= 1 else {
            throw ConfigurationError.invalidRegion(region)
        }
        guard padding >= 0 else {
            throw ConfigurationError.negativePadding(padding)
        }
    }
}

public struct CycleAction: Codable, Hashable, Sendable {
    public let placements: [MoveAction]

    public init(placements: [MoveAction]) {
        self.placements = placements
    }

    fileprivate func validate() throws {
        guard !placements.isEmpty else {
            throw ConfigurationError.emptyCycle
        }
        for placement in placements {
            try placement.validate()
        }
    }
}

public struct NudgeAction: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum Action: Equatable, Sendable {
    case move(MoveAction)
    case cycle(CycleAction)
    case nudge(NudgeAction)
    case focus(Direction)
    case hints
    case grid
}

extension Action: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case region
        case screen
        case padding
        case placements
        case x
        case y
        case direction
    }

    private enum Kind: String, Codable {
        case move
        case cycle
        case nudge
        case focus
        case hints
        case grid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .move:
            self = .move(MoveAction(
                region: try container.decode(NormalizedRect.self, forKey: .region),
                screen: try container.decodeIfPresent(ScreenTarget.self, forKey: .screen) ?? .current,
                padding: try container.decodeIfPresent(Double.self, forKey: .padding) ?? 0
            ))
        case .cycle:
            self = .cycle(CycleAction(
                placements: try container.decode([MoveAction].self, forKey: .placements)
            ))
        case .nudge:
            self = .nudge(NudgeAction(
                x: try container.decode(Double.self, forKey: .x),
                y: try container.decode(Double.self, forKey: .y)
            ))
        case .focus:
            self = .focus(try container.decode(Direction.self, forKey: .direction))
        case .hints:
            self = .hints
        case .grid:
            self = .grid
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .move(move):
            try container.encode(Kind.move, forKey: .type)
            try container.encode(move.region, forKey: .region)
            try container.encode(move.screen, forKey: .screen)
            try container.encode(move.padding, forKey: .padding)
        case let .cycle(cycle):
            try container.encode(Kind.cycle, forKey: .type)
            try container.encode(cycle.placements, forKey: .placements)
        case let .nudge(nudge):
            try container.encode(Kind.nudge, forKey: .type)
            try container.encode(nudge.x, forKey: .x)
            try container.encode(nudge.y, forKey: .y)
        case let .focus(direction):
            try container.encode(Kind.focus, forKey: .type)
            try container.encode(direction, forKey: .direction)
        case .hints:
            try container.encode(Kind.hints, forKey: .type)
        case .grid:
            try container.encode(Kind.grid, forKey: .type)
        }
    }
}

public enum ConfigurationError: LocalizedError, Equatable, Sendable {
    case unsupportedVersion(Int)
    case emptyKey
    case duplicateModifier(String)
    case duplicateBinding(String)
    case emptyCycle
    case invalidRegion(NormalizedRect)
    case negativePadding(Double)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "Configuration version \(version) is not supported."
        case .emptyKey:
            "A binding has an empty key."
        case let .duplicateModifier(key):
            "The binding for \(key) contains a duplicate modifier."
        case let .duplicateBinding(chord):
            "The keyboard shortcut \(chord) is configured more than once."
        case .emptyCycle:
            "A cycle action must contain at least one placement."
        case let .invalidRegion(region):
            "The normalized region \(region) extends outside its screen."
        case let .negativePadding(padding):
            "Window padding cannot be negative (received \(padding))."
        }
    }
}
