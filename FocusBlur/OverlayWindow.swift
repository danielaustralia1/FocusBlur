import AppKit

/// A borderless, transparent, click-through window that hosts an OverlayView.
/// Used as one of four region windows that surround the active window.
final class OverlayWindow: NSWindow {
    convenience init(rect: NSRect) {
        self.init(
            contentRect: rect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        animationBehavior = .none

        // Sit above normal windows but below floating panels
        level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)

        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let overlayView = OverlayView(frame: NSRect(origin: .zero, size: rect.size))
        contentView = overlayView
    }

    var overlayView: OverlayView? {
        contentView as? OverlayView
    }
}
