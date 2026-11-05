import AppKit

/// Menu-bar status item — required quit / settings affordance for LSUIElement apps.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let onOpenSettings: () -> Void
    private let onRefresh: () -> Void
    private let statusProvider: () -> (lastRefreshed: String, autoRefresh: String, isRefreshing: Bool)

    init(
        onOpenSettings: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        statusProvider: @escaping () -> (lastRefreshed: String, autoRefresh: String, isRefreshing: Bool)
    ) {
        self.onOpenSettings = onOpenSettings
        self.onRefresh = onRefresh
        self.statusProvider = statusProvider
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
        menu.delegate = self
        item.menu = menu
        statusItem = item
        rebuildMenu()
    }

    func rebuildMenu() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()

        let status = statusProvider()
        let refreshed = NSMenuItem(title: status.lastRefreshed, action: nil, keyEquivalent: "")
        refreshed.isEnabled = false
        menu.addItem(refreshed)

        let auto = NSMenuItem(title: status.autoRefresh, action: nil, keyEquivalent: "")
        auto.isEnabled = false
        menu.addItem(auto)

        menu.addItem(.separator())

        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self

        let refreshTitle = status.isRefreshing ? "Refreshing…" : "Refresh Usage"
        let refreshItem = menu.addItem(withTitle: refreshTitle, action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !status.isRefreshing

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit notchLLM", action: #selector(quit), keyEquivalent: "q")
            .target = self
    }

    func remove() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func refresh() {
        onRefresh()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
