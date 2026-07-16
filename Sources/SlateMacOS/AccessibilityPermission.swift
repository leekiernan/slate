import ApplicationServices
import Foundation

public enum AccessibilityPermission {
    public static func isGranted(promptIfNeeded: Bool = false) -> Bool {
        // The SDK imports this C global as mutable, which is rejected by Swift 6
        // concurrency checking even though the underlying CFString is constant.
        let options = ["AXTrustedCheckOptionPrompt": promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
