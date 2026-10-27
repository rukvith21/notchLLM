import SwiftUI

/// notchLLM — LSUIElement macOS agent with notch pill + menu-bar settings.
@main
struct NotchLLMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings scene kept so SwiftUI lifecycle stays alive; real prefs UI is
        // the AppKit window opened from the status-item menu.
        Settings {
            Text("Open Settings from the notchLLM menu-bar icon.")
                .padding()
        }
    }
}
