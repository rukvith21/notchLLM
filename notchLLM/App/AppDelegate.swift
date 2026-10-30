import AppKit
import SwiftUI

/// Application lifecycle for the LSUIElement agent.
/// Owns the notch panel, status item, settings window, and display observation.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?
    private var displayObserver: DisplayObserver?
    private var statusItemController: StatusItemController?
    private var settingsWindowController: SettingsWindowController?
    private let viewModel = NotchViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panel = NotchPanelController(viewModel: viewModel)
        panelController = panel
        panel.show()

        let settings = SettingsWindowController()
        settingsWindowController = settings

        let status = StatusItemController(
            onOpenSettings: { [weak self] in
                self?.settingsWindowController?.show()
            },
            onRefresh: { [weak self] in
                Task { await self?.viewModel.refresh() }
            }
        )
        statusItemController = status
        status.install()

        let observer = DisplayObserver { [weak panel] in
            panel?.repositionForActiveDisplay()
        }
        displayObserver = observer
        observer.start()

        viewModel.startObservingSettingsChanges()
        Task { await viewModel.refresh() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        displayObserver?.stop()
        panelController?.hide()
        statusItemController?.remove()
        viewModel.stopObservingSettingsChanges()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
