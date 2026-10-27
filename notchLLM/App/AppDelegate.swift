import AppKit
import SwiftUI

/// Application lifecycle for the LSUIElement agent.
/// Owns the notch panel controller and display observation.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?
    private var displayObserver: DisplayObserver?
    private let viewModel = NotchViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchPanelController(viewModel: viewModel)
        panelController = controller
        controller.show()

        let observer = DisplayObserver { [weak controller] in
            controller?.repositionForActiveDisplay()
        }
        displayObserver = observer
        observer.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        displayObserver?.stop()
        panelController?.hide()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
