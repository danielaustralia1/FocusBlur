import AppKit
import QuartzCore

/// Full-screen view that applies a GPU-composited Gaussian blur and semi-transparent
/// dim to everything behind it, with a rectangular cutout for the active window.
final class OverlayView: NSView {
    private var cutoutRect: NSRect = .zero
    private let maskLayer = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        guard let layer = self.layer else { return }

        // GPU-accelerated background blur via CIGaussianBlur
        if let blurFilter = CIFilter(name: "CIGaussianBlur") {
            blurFilter.setDefaults()
            blurFilter.setValue(Preferences.shared.blurRadius, forKey: kCIInputRadiusKey)
            layer.backgroundFilters = [blurFilter]
        }

        // Semi-transparent black for the dim effect
        let opacity = Preferences.shared.dimOpacity
        layer.backgroundColor = NSColor.black.withAlphaComponent(opacity).cgColor

        // Mask layer: filled everywhere except the cutout
        maskLayer.fillRule = .evenOdd
        layer.mask = maskLayer
        updateMask()
    }

    // MARK: - Public API

    /// Set the blur filter radius (0–30).
    func setBlurRadius(_ radius: Double) {
        guard let layer = self.layer,
              let filters = layer.backgroundFilters as? [CIFilter],
              let blur = filters.first else { return }
        blur.setValue(radius, forKey: kCIInputRadiusKey)
        // Reassign to trigger compositing update
        layer.backgroundFilters = [blur]
    }

    /// Set the dim overlay opacity (0.0–1.0).
    func setDimOpacity(_ opacity: Double) {
        layer?.backgroundColor = NSColor.black.withAlphaComponent(opacity).cgColor
    }

    /// Update the active-window cutout rectangle (in screen coordinates).
    /// Pass `.zero` to remove the cutout (blur/dim the entire screen).
    func setCutout(_ rect: NSRect) {
        cutoutRect = rect
        updateMask()
    }

    // MARK: - Mask

    private func updateMask() {
        let fullPath = CGMutablePath()
        fullPath.addRect(bounds)

        if cutoutRect != .zero {
            // Convert screen coordinates to this view's coordinate system.
            // Screen origin is bottom-left; the window's frame matches the screen,
            // so we offset by the window's origin.
            let windowOrigin = window?.frame.origin ?? .zero
            let localRect = NSRect(
                x: cutoutRect.origin.x - windowOrigin.x,
                y: cutoutRect.origin.y - windowOrigin.y,
                width: cutoutRect.width,
                height: cutoutRect.height
            )
            fullPath.addRect(localRect)
        }

        maskLayer.path = fullPath
        maskLayer.frame = bounds
    }

    override func layout() {
        super.layout()
        maskLayer.frame = bounds
        updateMask()
    }
}
