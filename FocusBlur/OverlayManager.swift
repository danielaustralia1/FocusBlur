import AppKit

/// Manages one fullscreen overlay window per display.
///
/// The key trick: instead of masking or cutting holes, the overlay window
/// is z-ordered just BELOW the active window using `order(.below, relativeTo:)`.
/// This means:
///   - The active window sits on top of the overlay → unaffected
///   - All inactive windows sit below the overlay → blurred + dimmed
///
/// This is the same approach used by HazeOver and similar apps.
final class OverlayManager {
    private var overlayWindows: [OverlayWindow] = []
    private var screenObserver: NSObjectProtocol?
    private var isVisible = false

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isVisible else { return }
            let lastWindowID = self.lastOrderedBelowID
            self.tearDown()
            self.showOverlays()
            if lastWindowID != 0 {
                self.orderBelow(windowID: lastWindowID)
            }
        }
    }

    private var lastOrderedBelowID: CGWindowID = 0

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        tearDown()
    }

    // MARK: - Show / Hide

    func showOverlays() {
        isVisible = true
        if overlayWindows.isEmpty { createOverlays() }
        for window in overlayWindows {
            window.orderFrontRegardless()
        }
    }

    func hideOverlays() {
        isVisible = false
        for window in overlayWindows {
            window.orderOut(nil)
        }
    }

    // MARK: - Z-order positioning

    /// Position all overlay windows just below the given window ID.
    /// The active window stays on top; everything else is behind the overlay.
    func orderBelow(windowID: CGWindowID) {
        guard isVisible, windowID != 0 else { return }
        lastOrderedBelowID = windowID

        let windowNumber = Int(windowID)
        for window in overlayWindows {
            window.order(.below, relativeTo: windowNumber)
        }
    }

    // MARK: - Update blur / dim

    func updateBlur(_ radius: Double) {
        for w in overlayWindows { w.overlayView?.setBlurRadius(radius) }
    }

    func updateDim(_ opacity: Double) {
        for w in overlayWindows { w.overlayView?.setDimOpacity(opacity) }
    }

    // MARK: - Private

    private func createOverlays() {
        for screen in NSScreen.screens {
            let overlay = OverlayWindow(screen: screen)
            overlayWindows.append(overlay)
        }
    }

    private func tearDown() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}
