import AppKit

/// A borderless, transparent, click-through window that covers an entire screen.
/// Hosts an OverlayView that provides blur + dim with a cutout for the active window.
final class OverlayWindow: NSWindow {
    convenience init(screen: NSScreen) {
        // Use the designated initializer (without screen:), then configure
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

        // Sit above normal windows but below floating panels.
        // NSWindow.Level 3 = .floating(3) minus 1, so we're just below floating.
        level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)

        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let overlayView = OverlayView(frame: screen.frame)
        contentView = overlayView
    }

    /// Convenience accessor for the overlay content.
    var overlayView: OverlayView? {
        contentView as? OverlayView
    }
}
