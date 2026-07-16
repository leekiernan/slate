import ApplicationServices
import Foundation
import SlateCore

@MainActor
public final class HotKeyService {
    public typealias Handler = @MainActor (Binding) -> Void

    private let handler: Handler
    private var bindings: [ResolvedBinding] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func start(bindings: [Binding]) throws {
        self.bindings = try bindings.map(ResolvedBinding.init)
        stop()

        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: slateEventTapCallback,
            userInfo: userInfo
        ) else {
            throw HotKeyError.cannotCreateEventTap
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            throw HotKeyError.cannotCreateRunLoopSource
        }

        self.eventTap = eventTap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    public func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        let relevantFlags = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
        guard let binding = bindings.first(where: {
            $0.keyCode == keyCode && $0.flags == relevantFlags
        }) else {
            return false
        }
        handler(binding.binding)
        return true
    }

    fileprivate func enableTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
}

private struct ResolvedBinding {
    let binding: Binding
    let keyCode: CGKeyCode
    let flags: CGEventFlags

    init(_ binding: Binding) throws {
        guard let keyCode = KeyCodes.value(for: binding.key) else {
            throw HotKeyError.unknownKey(binding.key)
        }
        self.binding = binding
        self.keyCode = keyCode
        flags = binding.modifiers.reduce(into: CGEventFlags()) { result, modifier in
            switch modifier {
            case .command: result.insert(.maskCommand)
            case .control: result.insert(.maskControl)
            case .option: result.insert(.maskAlternate)
            case .shift: result.insert(.maskShift)
            }
        }
    }
}

private enum KeyCodes {
    private static let values: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43,
        "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49,
        "escape": 53, "left": 123, "right": 124, "down": 125, "up": 126
    ]

    static func value(for key: String) -> CGKeyCode? {
        values[key.lowercased()]
    }
}

private func slateEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<HotKeyService>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { service.enableTap() }
        return Unmanaged.passUnretained(event)
    }
    guard type == .keyDown else { return Unmanaged.passUnretained(event) }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags.rawValue
    let handled = MainActor.assumeIsolated {
        service.handle(keyCode: keyCode, flags: CGEventFlags(rawValue: flags))
    }
    return handled ? nil : Unmanaged.passUnretained(event)
}

public enum HotKeyError: LocalizedError {
    case unknownKey(String)
    case cannotCreateEventTap
    case cannotCreateRunLoopSource

    public var errorDescription: String? {
        switch self {
        case let .unknownKey(key):
            "Unknown key in configuration: \(key)"
        case .cannotCreateEventTap:
            "Could not create the global keyboard event tap. Check Accessibility permission."
        case .cannotCreateRunLoopSource:
            "Could not attach the keyboard event tap to the application run loop."
        }
    }
}
