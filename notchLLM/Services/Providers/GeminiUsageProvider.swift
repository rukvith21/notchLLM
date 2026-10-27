import Foundation

/// Placeholder Gemini adapter. Phase 3 wires session / cookie credentials.
/// Phase 2 returns stable mock usage so the pill UI is demoable.
struct GeminiUsageProvider: UsageProviding {
    let kind: ProviderKind = .gemini

    func fetchUsage() async -> ProviderUsage {
        // TODO(Phase 3): read Gemini web session + remaining quota.
        try? await Task.sleep(for: .milliseconds(120))
        return .mock(
            for: .gemini,
            usedFraction: 0.68,
            tokensUsed: 680_000,
            tokensLimit: 1_000_000,
            resetsIn: 4 * 3_600 + 18 * 60,
            detail: "Mock Gemini Pro quota"
        )
    }
}
