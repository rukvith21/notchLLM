import AppKit

/// Describes where the notch pill should sit on a given `NSScreen`.
struct ScreenGeometry {
    let screen: NSScreen
    /// Visible frame (excludes menu bar / dock).
    let visibleFrame: NSRect
    /// Full screen frame in global coordinates.
    let frame: NSRect
    /// Approximate notch / unsafe top inset in points (0 on non-notch displays).
    let topUnsafeInset: CGFloat
    let hasNotch: Bool

    /// Prefer the screen that currently hosts the mouse, else main.
    static func preferred() -> ScreenGeometry? {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        else {
            return nil
        }
        return ScreenGeometry(screen: screen)
    }

    init(screen: NSScreen) {
        self.screen = screen
        self.frame = screen.frame
        self.visibleFrame = screen.visibleFrame

        // `safeAreaInsets` is available on notched MacBooks (macOS 12+).
        let inset = screen.safeAreaInsets.top
        self.topUnsafeInset = inset
        self.hasNotch = inset > 0
    }

    /// Top-centered origin hugging the display's top edge.
    /// On notched displays, the pill sits just under the absolute top so it
    /// visually flanks the hardware notch at status-bar level.
    func originForPanel(size: NSSize) -> NSPoint {
        let x = frame.midX - size.width / 2
        let y = frame.maxY - size.height - topPadding
        return NSPoint(x: x, y: y)
    }

    /// Small gap under the absolute top edge on non-notch displays.
    private var topPadding: CGFloat {
        hasNotch ? 0 : 2
    }
}
