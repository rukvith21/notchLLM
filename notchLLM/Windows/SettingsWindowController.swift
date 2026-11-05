import AppKit
import SwiftUI

/// Owns the preferences `NSWindow` hosting `SettingsView`.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let settingsViewModel = SettingsViewModel()

    func configure(onRequestRefresh: @escaping () -> Void) {
        settingsViewModel.onRequestRefresh = onRequestRefresh
    }

    func show() {
        if window == nil {
            build()
        }
        Task { await settingsViewModel.load() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }

    private func build() {
        let root = SettingsView(viewModel: settingsViewModel)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "notchLLM Settings"
        window.contentViewController = hosting
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
