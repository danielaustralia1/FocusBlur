import AppKit
import ApplicationServices

// Private AX function to extract the CGWindowID from an AXUIElement.
// This is the standard way apps like HazeOver, AltTab, etc. get the
// window number needed for z-order manipulation.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Tracks the frontmost window and provides its CGWindowID so the overlay
/// can be ordered just below it in the z-order.
///
/// Fires `onFocusedWindowChanged` with the window's CGWindowID whenever
/// the active window changes or .zero if no window is focused.
///
/// Retries every 2 seconds if Accessibility isn't yet granted.
final class WindowTracker {
    /// Called with the CGWindowID of the focused window (or 0 if none).
    var onFocusedWindowChanged: ((CGWindowID) -> Void)?

    private var workspaceObserver: NSObjectProtocol?
    private var pollTimer: Timer?
    private var accessibilityRetryTimer: Timer?
    private var axObserver: AXObserver?
    private var currentApp: NSRunningApplication?
    private var currentElement: AXUIElement?
    private var lastWindowID: CGWindowID = 0
    private var isAccessibilityTrusted = false

    // MARK: - Accessibility permission

    @discardableResult
    static func ensureAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Start / Stop

    func start() {
        WindowTracker.ensureAccessibility()
        isAccessibilityTrusted = AXIsProcessTrusted()

        if isAccessibilityTrusted {
            print("[FocusBlur] ✅ Accessibility trusted — window tracking active.")
            beginTracking()
        } else {
            print("[FocusBlur] ⏳ Waiting for Accessibility permission…")
            accessibilityRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                if AXIsProcessTrusted() {
                    print("[FocusBlur] ✅ Accessibility granted! Starting window tracking.")
                    timer.invalidate()
                    self.accessibilityRetryTimer = nil
                    self.isAccessibilityTrusted = true
                    self.beginTracking()
                }
            }
        }
    }

    func stop() {
        accessibilityRetryTimer?.invalidate()
        accessibilityRetryTimer = nil
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
        removeAXObserver()
        lastWindowID = 0
    }

    // MARK: - Internal

    private func beginTracking() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.trackApp(app)
        }

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            trackApp(frontApp)
        }

        // Poll to catch window changes AX notifications might miss (e.g. tab switches)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.refreshFocusedWindow()
        }
    }

    private func trackApp(_ app: NSRunningApplication) {
        if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }

        currentApp = app
        removeAXObserver()

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)

        guard result == .success, let window = windowValue else {
            if result == .apiDisabled {
                print("[FocusBlur] ❌ AX API disabled for \(app.localizedName ?? "unknown")")
            }
            onFocusedWindowChanged?(0)
            return
        }

        currentElement = (window as! AXUIElement)

        setupAXObserver(pid: pid, element: currentElement!)
        refreshFocusedWindow()
    }

    private func setupAXObserver(pid: pid_t, element: AXUIElement) {
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                tracker.refreshFocusedWindow()
            }
        }

        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, element, kAXMovedNotification as CFString, refcon)
        AXObserverAddNotification(observer, element, kAXResizedNotification as CFString, refcon)
        AXObserverAddNotification(observer, element, kAXFocusedWindowChangedNotification as CFString, refcon)

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.axObserver = observer
    }

    private func removeAXObserver() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        axObserver = nil
        currentElement = nil
    }

    // MARK: - Window ID extraction

    private func refreshFocusedWindow() {
        // If the current element is stale (app switched), re-query
        if let app = currentApp {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
               let window = windowValue {
                currentElement = (window as! AXUIElement)
            }
        }

        guard let element = currentElement else { return }

        var windowID: CGWindowID = 0
        let err = _AXUIElementGetWindow(element, &windowID)

        guard err == .success, windowID != 0 else { return }

        if windowID != lastWindowID {
            lastWindowID = windowID
            print("[FocusBlur] Focused window ID: \(windowID) (\(currentApp?.localizedName ?? "?"))")
            onFocusedWindowChanged?(windowID)
        }
    }
}
