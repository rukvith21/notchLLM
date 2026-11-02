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

    /// Right-edge origin for the CodeNotch-style vertical pill.
    /// Panel content keeps the slim bar on the trailing edge (plus a few points of
    /// shadow bleed); the left side grows for the hover tooltip only.
    func originForPanel(size: NSSize) -> NSPoint {
        let x = frame.maxX - size.width - rightPadding
        let y = visibleFrame.midY - size.height / 2
        return NSPoint(x: x, y: y)
    }

    /// Flush to the display's right edge (2pt breathing room avoids shadow clip).
    private var rightPadding: CGFloat { 2 }
}
