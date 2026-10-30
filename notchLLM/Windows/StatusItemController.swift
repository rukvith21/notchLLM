import AppKit

/// Menu-bar status item — required quit / settings affordance for LSUIElement apps.
@MainActor
final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private let onOpenSettings: () -> Void
    private let onRefresh: () -> Void

    init(onOpenSettings: @escaping () -> Void, onRefresh: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onRefresh = onRefresh
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(
                systemSymbolName: "circle.hexagongrid.circle.fill",
                accessibilityDescription: "notchLLM"
            ) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "nL"
            }
            button.toolTip = "notchLLM"
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(withTitle: "Refresh Usage", action: #selector(refresh), keyEquivalent: "r")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit notchLLM", action: #selector(quit), keyEquivalent: "q")
            .target = self
        item.menu = menu
        statusItem = item
    }

    func remove() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func refresh() {
        onRefresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
