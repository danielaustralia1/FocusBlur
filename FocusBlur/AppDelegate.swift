import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var overlayManager: OverlayManager?
    private var windowTracker: WindowTracker?
    private var shakeDetector: ShakeDetector?
    private var hotkeyManager: HotkeyManager?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let prefs = Preferences.shared

        if !AXIsProcessTrusted() {
            showAccessibilityPrompt()
        }

        overlayManager = OverlayManager()
        windowTracker = WindowTracker()
        shakeDetector = ShakeDetector()
        hotkeyManager = HotkeyManager()
        statusBarController = StatusBarController()

        // When the focused window changes, re-order overlays just below it
        windowTracker?.onFocusedWindowChanged = { [weak self] windowID in
            self?.overlayManager?.orderBelow(windowID: windowID)
        }

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

        shakeDetector?.onShakeDetected = {
            prefs.isEnabled.toggle()
        }

        // Sync shake sensitivity
        shakeDetector?.sensitivity = prefs.shakeSensitivity
        prefs.$shakeSensitivity
            .sink { [weak self] sensitivity in
                self?.shakeDetector?.sensitivity = sensitivity
            }
            .store(in: &cancellables)

        // Global hotkey
        hotkeyManager?.onHotkeyPressed = {
            prefs.isEnabled.toggle()
        }

        prefs.$hotkeyEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.hotkeyManager?.start()
                } else {
                    self?.hotkeyManager?.stop()
                }
            }
            .store(in: &cancellables)

        // Re-bind hotkey when user changes the shortcut
        prefs.$hotkeyKeyCode
            .combineLatest(prefs.$hotkeyModifiers)
            .dropFirst() // skip initial value
            .sink { [weak self] keyCode, modifiers in
                self?.hotkeyManager?.updateHotkey(
                    keyCode: UInt16(keyCode),
                    modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers))
                )
            }
            .store(in: &cancellables)

        if prefs.isEnabled {
            overlayManager?.showOverlays()
            windowTracker?.start()
        }
        if prefs.shakeToToggle {
            shakeDetector?.start()
        }
        if prefs.hotkeyEnabled {
            hotkeyManager?.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlayManager?.hideOverlays()
        windowTracker?.stop()
        shakeDetector?.stop()
        hotkeyManager?.stop()
    }

    // MARK: - Accessibility prompt

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
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
