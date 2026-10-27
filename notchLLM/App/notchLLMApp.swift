import SwiftUI

/// notchLLM — Phase 1 LSUIElement macOS agent.
/// Dock-less background app that hosts a floating NSPanel beside the notch.
@main
struct NotchLLMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings scene reserved for Phase 4; empty Commands keeps SwiftUI lifecycle alive
        // without a visible window (the notch panel is owned by AppKit).
        Settings {
            EmptyView()
        }
    }
}
