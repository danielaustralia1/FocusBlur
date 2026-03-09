import AppKit
import QuartzCore

/// Full-screen view that applies blur + dim to everything behind it,
/// with a rectangular cutout that lets the active window show through.
///
/// Blur uses NSVisualEffectView (reliable, GPU-composited by WindowServer).
/// Dim uses a separate view drawing semi-transparent black with a cleared cutout.
final class OverlayView: NSView {
    private let blurView = NSVisualEffectView()
    private let dimView = DimView()
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

        // --- Blur: NSVisualEffectView blurs everything behind this window ---
        blurView.material = .fullScreenUI
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.frame = bounds
        blurView.autoresizingMask = [.width, .height]
        blurView.alphaValue = CGFloat(Preferences.shared.blurRadius / 30.0)
        addSubview(blurView)

        // --- Dim: semi-transparent black overlay, drawn with a cutout hole ---
        dimView.frame = bounds
        dimView.autoresizingMask = [.width, .height]
        dimView.dimOpacity = Preferences.shared.dimOpacity
        addSubview(dimView)
    }

    // MARK: - Public API

    /// Set blur intensity. Slider range 0–30 is mapped to NSVisualEffectView alpha 0–1.
    func setBlurRadius(_ radius: Double) {
        blurView.alphaValue = CGFloat(max(min(radius / 30.0, 1.0), 0.0))
    }

    /// Set dim overlay opacity (0.0–1.0).
    func setDimOpacity(_ opacity: Double) {
        dimView.dimOpacity = opacity
    }

    /// Update the active-window cutout rectangle (in screen coordinates).
    /// Pass `.zero` to remove the cutout (blur/dim the entire screen).
    func setCutout(_ rect: NSRect) {
        cutoutRect = rect
        let local = localCutoutRect()
        updateBlurMask(local)
        dimView.cutoutRect = local
    }

    // MARK: - Coordinate conversion

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

    // MARK: - Blur mask

    /// NSVisualEffectView.maskImage: opaque = show blur, clear = no blur.
    private func updateBlurMask(_ localRect: NSRect) {
        guard localRect != .zero else {
            blurView.maskImage = nil  // No cutout → blur everywhere
            return
        }
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            // Punch a transparent hole using .copy compositing
            NSColor.clear.setFill()
            localRect.fill(using: .copy)
            return true
        }
        blurView.maskImage = image
    }

    override func layout() {
        super.layout()
        let local = localCutoutRect()
        updateBlurMask(local)
        dimView.cutoutRect = local
    }
}

// MARK: - DimView

/// Draws a semi-transparent black overlay with a rectangular cutout cleared to transparent.
/// Uses NSCompositingOperation.copy to punch a true transparent hole in the dim layer.
private final class DimView: NSView {
    var dimOpacity: Double = 0.4 {
        didSet { needsDisplay = true }
    }
    var cutoutRect: NSRect = .zero {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        // Fill the entire view with semi-transparent black
        NSColor.black.withAlphaComponent(dimOpacity).setFill()
        bounds.fill()

        // Punch a transparent hole for the active window.
        // .copy compositing replaces whatever is there with clear (transparent).
        if cutoutRect != .zero {
            NSColor.clear.setFill()
            cutoutRect.fill(using: .copy)
        }
    }
}
