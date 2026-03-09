import AppKit
import ApplicationServices

/// Tracks the frontmost window's position and size using the Accessibility API.
/// Fires `onActiveWindowChanged` whenever the active window moves, resizes,
/// or a different window is activated.
final class WindowTracker {
    var onActiveWindowChanged: ((CGRect) -> Void)?

    private var workspaceObserver: NSObjectProtocol?
    private var pollTimer: Timer?
    private var axObserver: AXObserver?
    private var currentApp: NSRunningApplication?
    private var currentElement: AXUIElement?
    private var lastFrame: CGRect = .zero

    // MARK: - Start / Stop

    func start() {
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

        // Light poll as a safety net for missed AX notifications (e.g. drag without notification).
        // 0.1s is fast enough for smooth visual updates but cheap in CPU.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.refreshActiveWindowFrame()
        }
    }

    func stop() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
        removeAXObserver()
    }

    // MARK: - Accessibility tracking

    private func trackApp(_ app: NSRunningApplication) {
        // Skip our own app
        if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }

        currentApp = app
        removeAXObserver()

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get the focused window
        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)
        guard result == .success, let window = windowValue else {
            // App may not have a window (e.g. Finder desktop); clear cutout
            onActiveWindowChanged?(.zero)
            return
        }
        currentElement = (window as! AXUIElement)

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
        AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        // AX coordinates have origin at top-left; convert to Cocoa's bottom-left origin
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let frame = CGRect(
            x: position.x,
            y: screenHeight - position.y - size.height,
            width: size.width,
            height: size.height
        )

        if frame != lastFrame {
            lastFrame = frame
            onActiveWindowChanged?(frame)
        }
    }
}
