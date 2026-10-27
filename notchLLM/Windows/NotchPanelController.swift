import AppKit
import QuartzCore
import SwiftUI

/// Owns the floating `NotchPanel`, hosts SwiftUI content, and keeps the
/// panel flush to the active display's right edge (CodeNotch layout).
@MainActor
final class NotchPanelController {
    private let viewModel: NotchViewModel
    private var panel: NotchPanel?
    private var hostingView: NSHostingView<NotchPillView>?

    /// Tracks current content size so screen changes keep the right-edge anchor.
    private var contentSize = CGSize(width: 298, height: 176)

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        if panel == nil {
            buildPanel()
        }
        repositionForActiveDisplay()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func repositionForActiveDisplay() {
        applyFrame(size: contentSize, animate: false)
    }

    // MARK: - Private

    private func buildPanel() {
        let panel = NotchPanel(contentRect: NSRect(origin: .zero, size: contentSize))
        let root = NotchPillView(viewModel: viewModel) { [weak self] size in
            self?.handleContentSizeChange(size)
        }
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: contentSize)
        hosting.autoresizingMask = [.width, .height]
        // Clear hosting backdrop so only the drawn black pill/tooltip are visible.
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting
    }

    private func handleContentSizeChange(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let changed = abs(size.width - contentSize.width) > 0.5
            || abs(size.height - contentSize.height) > 0.5
        contentSize = size
        guard changed else { return }
        applyFrame(size: size, animate: false)
    }

    private func applyFrame(size: CGSize, animate: Bool) {
        guard let panel, let geometry = ScreenGeometry.preferred() else { return }
        let origin = geometry.originForPanel(size: NSSize(width: size.width, height: size.height))
        let frame = NSRect(origin: origin, size: size)
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
        hostingView?.frame = NSRect(origin: .zero, size: size)
    }
}
