import Foundation
import SlateCore
import Testing

@Test
func decodesVersionedConfiguration() throws {
    let data = Data(
        #"""
        {
          "version": 1,
          "bindings": [
            {
              "key": "h",
              "modifiers": ["control", "option"],
              "action": {
                "type": "move",
                "region": { "x": 0, "y": 0, "width": 0.5, "height": 1 },
                "screen": "current",
                "padding": 8
              }
            },
            {
              "key": "left",
              "modifiers": ["control", "option"],
              "action": { "type": "focus", "direction": "left" }
            }
          ]
        }
        """#.utf8
    )

    let configuration = try ConfigurationLoader().load(data: data)

    #expect(configuration.bindings.count == 2)
    #expect(configuration.bindings[0].action == .move(MoveAction(
        region: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1),
        screen: .current,
        padding: 8
    )))
    #expect(configuration.bindings[1].action == .focus(.left))
}

@Test
func rejectsDuplicateBindings() throws {
    let binding = Binding(key: "h", modifiers: [.option, .control], action: .hints)
    let duplicate = Binding(key: "h", modifiers: [.control, .option], action: .grid)

    do {
        try AppConfiguration(bindings: [binding, duplicate]).validate()
        Issue.record("Expected duplicate binding validation to fail")
    } catch let error as ConfigurationError {
        #expect(error == .duplicateBinding("h+control+option"))
    }
}

@Test
func rejectsRegionsOutsideTheScreen() throws {
    let configuration = AppConfiguration(bindings: [
        Binding(
            key: "x",
            modifiers: [.control],
            action: .move(MoveAction(region: NormalizedRect(x: 0.75, y: 0, width: 0.5, height: 1)))
        )
    ])

    do {
        try configuration.validate()
        Issue.record("Expected invalid region validation to fail")
    } catch let error as ConfigurationError {
        #expect(error == .invalidRegion(NormalizedRect(x: 0.75, y: 0, width: 0.5, height: 1)))
    }
}

@Test
func rejectsEmptyCycles() throws {
    let configuration = AppConfiguration(bindings: [
        Binding(
            key: "right",
            modifiers: [.command, .control],
            action: .cycle(CycleAction(placements: []))
        )
    ])

    do {
        try configuration.validate()
        Issue.record("Expected an empty cycle to fail validation")
    } catch let error as ConfigurationError {
        #expect(error == .emptyCycle)
    }
}

@Test
func roundTripsEveryActionKind() throws {
    let configuration = AppConfiguration(bindings: [
        Binding(
            key: "m",
            modifiers: [.control],
            action: .move(MoveAction(
                region: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                screen: .next,
                padding: 4
            ))
        ),
        Binding(
            key: "c",
            modifiers: [.control],
            action: .cycle(CycleAction(placements: [
                MoveAction(region: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1)),
                MoveAction(region: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
            ]))
        ),
        Binding(
            key: "n",
            modifiers: [.option],
            action: .nudge(NudgeAction(x: 0.125, y: -0.125))
        ),
        Binding(key: "f", modifiers: [.option], action: .focus(.down)),
        Binding(key: "h", modifiers: [.command], action: .hints),
        Binding(key: "g", modifiers: [.shift], action: .grid)
    ])

    let encoded = try JSONEncoder().encode(configuration)
    let decoded = try ConfigurationLoader().load(data: encoded)

    #expect(decoded == configuration)
}
