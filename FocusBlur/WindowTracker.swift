import AppKit
import ApplicationServices

/// Tracks the frontmost window's position and size using the Accessibility API.
/// Fires `onActiveWindowChanged` whenever the active window moves, resizes,
/// or a different window is activated.
///
/// If Accessibility permissions aren't yet granted, retries every 2 seconds
/// until they are — no app restart needed.
final class WindowTracker {
    var onActiveWindowChanged: ((CGRect) -> Void)?

    private var workspaceObserver: NSObjectProtocol?
    private var pollTimer: Timer?
    private var accessibilityRetryTimer: Timer?
    private var axObserver: AXObserver?
    private var currentApp: NSRunningApplication?
    private var currentElement: AXUIElement?
    private var lastFrame: CGRect = .zero
    private var isAccessibilityTrusted = false

    // MARK: - Accessibility permission

    /// Check (and optionally prompt) for Accessibility trust.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Start / Stop

    func start() {
        // Prompt for accessibility
        WindowTracker.ensureAccessibility()
        isAccessibilityTrusted = AXIsProcessTrusted()

        if isAccessibilityTrusted {
            print("[FocusBlur] ✅ Accessibility trusted — window tracking active.")
            beginTracking()
        } else {
            print("[FocusBlur] ⏳ Waiting for Accessibility permission… (grant in System Settings → Privacy & Security → Accessibility)")
            // Poll every 2s until the user grants permission — no restart needed.
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
        lastFrame = .zero
    }

    // MARK: - Internal setup

    private func beginTracking() {
        // Observe app activation changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.trackApp(app)
        }

        // Track the currently active app right away
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            trackApp(frontApp)
        }

        // Light poll as a safety net for missed AX notifications (e.g. window drag).
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.refreshActiveWindowFrame()
        }
    }

    // MARK: - Accessibility tracking

    private func trackApp(_ app: NSRunningApplication) {
        // Skip our own app — when our popover activates, keep showing the last cutout
        if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }

        currentApp = app
        removeAXObserver()

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get the focused window
        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)

        guard result == .success, let window = windowValue else {
            if result == .apiDisabled {
                print("[FocusBlur] ❌ AX API disabled for \(app.localizedName ?? "unknown"). Is Accessibility granted?")
            } else if result == .noValue {
                // App has no focused window (e.g. Finder desktop) — clear cutout
                print("[FocusBlur] App '\(app.localizedName ?? "?")' has no focused window, clearing cutout.")
            } else {
                print("[FocusBlur] ❌ AX query failed for '\(app.localizedName ?? "?")': error \(result.rawValue)")
            }
            onActiveWindowChanged?(.zero)
            return
        }

        currentElement = (window as! AXUIElement)
        print("[FocusBlur] Tracking window for '\(app.localizedName ?? "?")'")

        setupAXObserver(pid: pid, element: currentElement!)
        refreshActiveWindowFrame()
    }

    private func setupAXObserver(pid: pid_t, element: AXUIElement) {
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                tracker.refreshActiveWindowFrame()
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

    // MARK: - Frame reading

    private func refreshActiveWindowFrame() {
        guard let element = currentElement else { return }

        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success
        else { return }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return }

        // AX coordinates: origin at top-left of primary screen.
        // Cocoa coordinates: origin at bottom-left of primary screen.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let frame = CGRect(
            x: position.x,
            y: primaryHeight - position.y - size.height,
            width: size.width,
            height: size.height
        )

        if frame != lastFrame {
            lastFrame = frame
            print("[FocusBlur] Cutout → x:\(Int(frame.origin.x)) y:\(Int(frame.origin.y)) w:\(Int(frame.width)) h:\(Int(frame.height))")
            onActiveWindowChanged?(frame)
        }
    }
}
