import AppKit

/// Observes screen parameter / workspace changes and invokes a callback
/// so the notch panel can re-anchor across multi-display / sleep / notch flips.
@MainActor
final class DisplayObserver: NSObject {
    private let onChange: () -> Void
    private var isRunning = false

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleDisplayChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleDisplayChange),
            name: NSWindow.didChangeScreenNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDisplayChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleDisplayChange(_ notification: Notification) {
        onChange()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
