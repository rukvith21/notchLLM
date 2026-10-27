import AppKit
import SwiftUI

/// Owns the floating `NotchPanel`, hosts SwiftUI content, and keeps the
/// panel aligned to the active display's notch / top-center geometry.
@MainActor
final class NotchPanelController {
    private let viewModel: NotchViewModel
    private var panel: NotchPanel?
    private var hostingView: NSHostingView<NotchPillView>?

    /// Default Phase-1 pill size; Phase 2 will size to content.
    private let panelSize = NSSize(width: 220, height: 36)

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
        guard let panel, let geometry = ScreenGeometry.preferred() else { return }
        let origin = geometry.originForPanel(size: panelSize)
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }

    // MARK: - Private

    private func buildPanel() {
        let panel = NotchPanel(contentRect: NSRect(origin: .zero, size: panelSize))
        let root = NotchPillView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: panelSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting
    }
}
