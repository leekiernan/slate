import SlateCore

enum DefaultConfiguration {
    static let value = AppConfiguration(
        bindings: [
            Binding(
                key: "h",
                modifiers: [.control, .option],
                action: .move(MoveAction(
                    region: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1),
                    padding: 6
                ))
            ),
            Binding(
                key: "l",
                modifiers: [.control, .option],
                action: .move(MoveAction(
                    region: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1),
                    padding: 6
                ))
            ),
            Binding(
                key: "return",
                modifiers: [.control, .option],
                action: .move(MoveAction(
                    region: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                    padding: 6
                ))
            ),
            Binding(key: "left", modifiers: [.control, .option], action: .focus(.left)),
            Binding(key: "right", modifiers: [.control, .option], action: .focus(.right)),
            Binding(key: "up", modifiers: [.control, .option], action: .focus(.up)),
            Binding(key: "down", modifiers: [.control, .option], action: .focus(.down)),
            Binding(key: "space", modifiers: [.control, .option], action: .hints),
            Binding(key: "g", modifiers: [.control, .option], action: .grid)
        ]
    )
}
