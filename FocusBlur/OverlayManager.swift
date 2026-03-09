import AppKit

/// Manages four overlay windows positioned around the active window:
///
///     +------------------------------+
///     |            TOP               |
///     +------+---------------+-------+
///     |      |               |       |
///     | LEFT | Active Window | RIGHT |
///     |      |   (no overlay)|       |
///     +------+---------------+-------+
///     |           BOTTOM             |
///     +------------------------------+
///
/// The active window is never covered — no masking needed.
/// Each overlay window independently blurs and dims its region.
final class OverlayManager {
    private var topWindow: OverlayWindow?
    private var bottomWindow: OverlayWindow?
    private var leftWindow: OverlayWindow?
    private var rightWindow: OverlayWindow?

    private var screenObserver: NSObjectProtocol?
    private var isVisible = false

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isVisible else { return }
            self.tearDown()
            self.showOverlays()
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
        isVisible = true
        if topWindow == nil { createWindows() }
        // Start covering everything; updateCutout will carve out the active window
        updateCutout(.zero)
        for w in allWindows { w.orderFrontRegardless() }
    }

    func hideOverlays() {
        isVisible = false
        for w in allWindows { w.orderOut(nil) }
    }

    // MARK: - Update

    /// Reposition the four overlay windows around the active window's frame.
    /// Pass `.zero` when there's no active window (covers everything).
    func updateCutout(_ activeFrame: CGRect) {
        guard isVisible else { return }
        let bounds = totalBounds()

        // No active window or accessibility not working → cover everything
        if activeFrame == .zero || activeFrame.isEmpty {
            applyFrame(topWindow, frame: bounds)
            applyFrame(bottomWindow, frame: .zero)
            applyFrame(leftWindow, frame: .zero)
            applyFrame(rightWindow, frame: .zero)
            return
        }

        // Clamp the active window rect to the total screen area
        let cutout = activeFrame.intersection(bounds)
        guard !cutout.isNull, !cutout.isEmpty else {
            applyFrame(topWindow, frame: bounds)
            applyFrame(bottomWindow, frame: .zero)
            applyFrame(leftWindow, frame: .zero)
            applyFrame(rightWindow, frame: .zero)
            return
        }

        // Top: full width, from the top of the active window to the top of all screens
        let top = CGRect(
            x: bounds.minX,
            y: cutout.maxY,
            width: bounds.width,
            height: bounds.maxY - cutout.maxY
        )

        // Bottom: full width, from the bottom of all screens to the bottom of the active window
        let bottom = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: cutout.minY - bounds.minY
        )

        // Left: between top and bottom, from left edge of screens to active window left
        let left = CGRect(
            x: bounds.minX,
            y: cutout.minY,
            width: cutout.minX - bounds.minX,
            height: cutout.height
        )

        // Right: between top and bottom, from active window right to right edge of screens
        let right = CGRect(
            x: cutout.maxX,
            y: cutout.minY,
            width: bounds.maxX - cutout.maxX,
            height: cutout.height
        )

        applyFrame(topWindow, frame: top)
        applyFrame(bottomWindow, frame: bottom)
        applyFrame(leftWindow, frame: left)
        applyFrame(rightWindow, frame: right)
    }

    func updateBlur(_ radius: Double) {
        for w in allWindows { w.overlayView?.setBlurRadius(radius) }
    }

    func updateDim(_ opacity: Double) {
        for w in allWindows { w.overlayView?.setDimOpacity(opacity) }
    }

    // MARK: - Private

    /// Union of all connected screens.
    private func totalBounds() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    private func createWindows() {
        let b = totalBounds()
        topWindow = OverlayWindow(rect: b)
        bottomWindow = OverlayWindow(rect: b)
        leftWindow = OverlayWindow(rect: b)
        rightWindow = OverlayWindow(rect: b)
    }

    private func applyFrame(_ window: OverlayWindow?, frame: CGRect) {
        guard let window else { return }
        if frame.width >= 1 && frame.height >= 1 {
            window.setFrame(frame, display: true)
            if !window.isVisible { window.orderFrontRegardless() }
        } else {
            window.orderOut(nil)
        }
    }

    private var allWindows: [OverlayWindow] {
        [topWindow, bottomWindow, leftWindow, rightWindow].compactMap { $0 }
    }

    private func tearDown() {
        for w in allWindows { w.orderOut(nil) }
        topWindow = nil
        bottomWindow = nil
        leftWindow = nil
        rightWindow = nil
    }
}
