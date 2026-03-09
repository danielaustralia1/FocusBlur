import AppKit

/// Creates and manages one overlay window per connected display.
/// Handles display configuration changes (monitors added/removed).
final class OverlayManager {
    private var overlayWindows: [OverlayWindow] = []
    private var screenObserver: NSObjectProtocol?

    init() {
        // Rebuild overlays when displays change
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let wasVisible = !self.overlayWindows.isEmpty && self.overlayWindows.first?.isVisible == true
            self.tearDown()
            if wasVisible {
                self.showOverlays()
            }
        }
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        tearDown()
    }

    // MARK: - Show / Hide

    func showOverlays() {
        if overlayWindows.isEmpty {
            createOverlays()
        }
        for window in overlayWindows {
            window.orderFrontRegardless()
        }
    }

    func hideOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
    }

    // MARK: - Update

    func updateCutout(_ frame: CGRect) {
        for window in overlayWindows {
            window.overlayView?.setCutout(frame)
        }
    }

    func updateBlur(_ radius: Double) {
        for window in overlayWindows {
            window.overlayView?.setBlurRadius(radius)
        }
    }

    func updateDim(_ opacity: Double) {
        for window in overlayWindows {
            window.overlayView?.setDimOpacity(opacity)
        }
    }

    // MARK: - Internal

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
