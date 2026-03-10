import AppKit

/// A borderless, transparent, click-through fullscreen overlay window.
/// Positioned just below the active window in z-order using order(.below, relativeTo:).
final class OverlayWindow: NSWindow {
    convenience init(screen: NSScreen) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        animationBehavior = .none

        // Normal level — same as other windows. We control visibility by
        // z-ordering this window just below the active window.
        level = .normal

        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let overlayView = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        contentView = overlayView
    }

    // Prevent this window from ever becoming key or main
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    var overlayView: OverlayView? {
        contentView as? OverlayView
    }
}
