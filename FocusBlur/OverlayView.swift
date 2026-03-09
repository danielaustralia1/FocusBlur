import AppKit
import QuartzCore

/// Full-screen overlay that applies blur + dim behind it, with a rectangular
/// cutout that lets the active window show through unaffected.
///
/// Architecture: a single CAShapeLayer mask on this view's layer clips
/// ALL content (blur + dim subviews) at once — the cutout area is simply
/// not rendered, so the active window shows through cleanly.
final class OverlayView: NSView {
    private let blurView = NSVisualEffectView()
    private let dimView = NSView()
    private let cutoutMask = CAShapeLayer()
    private var cutoutRect: NSRect = .zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.isOpaque = false

        // --- Blur via NSVisualEffectView ---
        blurView.material = .fullScreenUI
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.frame = bounds
        blurView.autoresizingMask = [.width, .height]
        blurView.alphaValue = CGFloat(Preferences.shared.blurRadius / 30.0)
        addSubview(blurView)

        // --- Dim via a simple colored view on top ---
        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(Preferences.shared.dimOpacity).cgColor
        dimView.frame = bounds
        dimView.autoresizingMask = [.width, .height]
        addSubview(dimView)

        // --- Single mask on this view's layer clips everything (blur + dim) ---
        cutoutMask.fillRule = .evenOdd
        cutoutMask.fillColor = NSColor.white.cgColor
        cutoutMask.frame = bounds
        layer?.mask = cutoutMask
        updateMask(.zero)
    }

    // MARK: - Public API

    func setBlurRadius(_ radius: Double) {
        blurView.alphaValue = CGFloat(max(min(radius / 30.0, 1.0), 0.0))
    }

    func setDimOpacity(_ opacity: Double) {
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(opacity).cgColor
    }

    func setCutout(_ rect: NSRect) {
        cutoutRect = rect
        updateMask(localCutoutRect())
    }

    // MARK: - Private

    /// Convert screen coordinates → this view's local coordinate system.
    private func localCutoutRect() -> NSRect {
        guard cutoutRect != .zero else { return .zero }
        let origin = window?.frame.origin ?? .zero
        return NSRect(
            x: cutoutRect.origin.x - origin.x,
            y: cutoutRect.origin.y - origin.y,
            width: cutoutRect.width,
            height: cutoutRect.height
        )
    }

    /// Update the shape mask. EvenOdd fill rule: the full rect is filled,
    /// then the inner cutout rect is subtracted → transparent hole.
    private func updateMask(_ localRect: NSRect) {
        let path = CGMutablePath()
        path.addRect(bounds)
        if localRect != .zero {
            path.addRect(localRect)
        }
        cutoutMask.path = path
        cutoutMask.frame = bounds
    }

    override func layout() {
        super.layout()
        cutoutMask.frame = bounds
        updateMask(localCutoutRect())
    }
}
