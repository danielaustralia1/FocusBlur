import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var overlayManager: OverlayManager?
    private var windowTracker: WindowTracker?
    private var shakeDetector: ShakeDetector?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let prefs = Preferences.shared

        // Show a user-facing alert if Accessibility isn't enabled yet.
        if !AXIsProcessTrusted() {
            showAccessibilityPrompt()
        }

        overlayManager = OverlayManager()
        windowTracker = WindowTracker()
        shakeDetector = ShakeDetector()
        statusBarController = StatusBarController()

        // Feed active-window frame changes into the overlay manager
        windowTracker?.onActiveWindowChanged = { [weak self] frame in
            self?.overlayManager?.updateCutout(frame)
        }

        // React to preference changes
        prefs.$isEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.overlayManager?.showOverlays()
                    self?.windowTracker?.start()
                } else {
                    self?.overlayManager?.hideOverlays()
                    self?.windowTracker?.stop()
                }
            }
            .store(in: &cancellables)

        prefs.$blurRadius
            .sink { [weak self] radius in
                self?.overlayManager?.updateBlur(radius)
            }
            .store(in: &cancellables)

        prefs.$dimOpacity
            .sink { [weak self] opacity in
                self?.overlayManager?.updateDim(opacity)
            }
            .store(in: &cancellables)

        prefs.$shakeToToggle
            .sink { [weak self] enabled in
                if enabled {
                    self?.shakeDetector?.start()
                } else {
                    self?.shakeDetector?.stop()
                }
            }
            .store(in: &cancellables)

        // Shake toggles the main enable switch
        shakeDetector?.onShakeDetected = {
            prefs.isEnabled.toggle()
        }

        // Kick things off
        if prefs.isEnabled {
            overlayManager?.showOverlays()
            windowTracker?.start()
        }
        if prefs.shakeToToggle {
            shakeDetector?.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlayManager?.hideOverlays()
        windowTracker?.stop()
        shakeDetector?.stop()
    }

    // MARK: - Accessibility prompt

    /// Shows a native alert explaining why Accessibility is needed,
    /// with a button that opens System Settings directly to the right pane.
    private func showAccessibilityPrompt() {
        let alert = NSAlert()
        alert.messageText = "FocusBlur Needs Accessibility Access"
        alert.informativeText = "To track the active window and only blur inactive ones, FocusBlur needs Accessibility permissions.\n\nClick \"Open System Settings\" and toggle FocusBlur on. It will start working automatically — no restart needed."
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: nil)
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Deep-link straight to Privacy → Accessibility
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
