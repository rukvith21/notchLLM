import Foundation

/// Placeholder ChatGPT adapter. Phase 3 wires account session / API.
/// Phase 2 returns stable mock usage so the pill UI is demoable.
struct ChatGPTUsageProvider: UsageProviding {
    let kind: ProviderKind = .chatGPT

    func fetchUsage() async -> ProviderUsage {
        // TODO(Phase 3): read ChatGPT usage remaining.
        try? await Task.sleep(for: .milliseconds(90))
        return .mock(
            for: .chatGPT,
            usedFraction: 0.42,
            tokensUsed: 42_000,
            tokensLimit: 100_000,
            resetsIn: 2 * 86_400 + 5 * 3_600,
            detail: "Mock ChatGPT Plus messages"
        )
    }
}
