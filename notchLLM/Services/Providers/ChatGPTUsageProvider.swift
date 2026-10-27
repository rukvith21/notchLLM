import Foundation

/// Placeholder ChatGPT adapter. Phase 3 wires account session / API.
struct ChatGPTUsageProvider: UsageProviding {
    let kind: ProviderKind = .chatGPT

    func fetchUsage() async -> ProviderUsage {
        // TODO(Phase 3): read ChatGPT usage remaining.
        ProviderUsage.placeholder(for: .chatGPT)
    }
}
