import Foundation

/// Placeholder Gemini adapter. Phase 3 wires session / cookie credentials.
struct GeminiUsageProvider: UsageProviding {
    let kind: ProviderKind = .gemini

    func fetchUsage() async -> ProviderUsage {
        // TODO(Phase 3): read Gemini web session + remaining quota.
        ProviderUsage.placeholder(for: .gemini)
    }
}
