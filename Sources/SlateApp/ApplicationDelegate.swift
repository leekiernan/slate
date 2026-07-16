import AppKit
import SlateCore
import SlateMacOS

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private let desktop = AccessibilityDesktop()
    private let overlays = PendingOverlaySystem()
    private lazy var engine = OperationEngine(desktop: desktop, overlays: overlays)
    private lazy var hotKeys = HotKeyService { [weak self] binding in
        self?.execute(binding.action)
    }

    private var statusItem: NSStatusItem?
    private var configurationStore: ConfigurationStore?
    private var configuration: AppConfiguration?
    private var accessibilityGranted: Bool?
    private var accessibilityMonitor: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildStatusMenu()

        do {
            configurationStore = try ConfigurationStore()
            try reloadConfiguration()
        } catch {
            present(error)
        }

        if !AccessibilityPermission.isGranted() {
            _ = AccessibilityPermission.isGranted(promptIfNeeded: true)
        }
        startAccessibilityMonitoring()
        refreshAccessibilityState()
        updateStatusMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityMonitor?.invalidate()
    }

    private func buildStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(named: "MenuBarIcon")
        image?.size = NSSize(width: 18, height: 18)
        item.button?.image = image
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Slate"
        statusItem = item
        updateStatusMenu()
    }

    private func updateStatusMenu() {
        let menu = NSMenu()

        let permission = AccessibilityPermission.isGranted() ? "Accessibility: Enabled" : "Accessibility: Required"
        let permissionItem = NSMenuItem(title: permission, action: #selector(requestAccessibility), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(.separator())

        let reload = NSMenuItem(title: "Reload Configuration", action: #selector(reloadConfigurationFromMenu), keyEquivalent: "r")
        reload.target = self
        menu.addItem(reload)

        let open = NSMenuItem(title: "Open Configuration", action: #selector(openConfiguration), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)

        if let configuration {
            menu.addItem(.separator())
            let heading = NSMenuItem(title: "\(configuration.bindings.count) bindings loaded", action: nil, keyEquivalent: "")
            heading.isEnabled = false
            menu.addItem(heading)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Slate", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    private func reloadConfiguration() throws {
        guard let configurationStore else { return }
        let configuration = try configurationStore.loadOrCreateDefault()
        self.configuration = configuration

        let isGranted = AccessibilityPermission.isGranted()
        accessibilityGranted = isGranted
        if isGranted {
            try hotKeys.start(bindings: configuration.bindings)
        } else {
            hotKeys.stop()
        }
        updateStatusMenu()
    }

    private func startAccessibilityMonitoring() {
        accessibilityMonitor = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(refreshAccessibilityState),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func refreshAccessibilityState() {
        let isGranted = AccessibilityPermission.isGranted()
        guard isGranted != accessibilityGranted else { return }

        accessibilityGranted = isGranted
        if isGranted {
            do {
                try reloadConfiguration()
            } catch {
                present(error)
            }
        } else {
            hotKeys.stop()
            updateStatusMenu()
        }
    }

    private func execute(_ action: Action) {
        do {
            try engine.execute(action)
        } catch {
            present(error)
        }
    }

    @objc private func requestAccessibility() {
        if AccessibilityPermission.isGranted(promptIfNeeded: true) {
            try? reloadConfiguration()
        } else if let settingsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) {
            NSWorkspace.shared.open(settingsURL)
        }
        updateStatusMenu()
    }

    @objc private func reloadConfigurationFromMenu() {
        do {
            try reloadConfiguration()
        } catch {
            present(error)
        }
    }

    @objc private func openConfiguration() {
        guard let fileURL = configurationStore?.fileURL else { return }
        NSWorkspace.shared.open(fileURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func present(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
