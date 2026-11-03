import Foundation

/// Fans out to providers concurrently — never blocks the main thread.
actor UsageAggregator: UsageAggregating {
    private let providers: [any UsageProviding]

    init(providers: [any UsageProviding]? = nil) {
        // Match ProviderKind display order (ChatGPT → Cursor → Gemini).
        self.providers = providers ?? [
            ChatGPTUsageProvider(),
            CursorUsageProvider(),
            GeminiUsageProvider()
        ]
    }

    func refreshAll() async -> [ProviderUsage] {
        await withTaskGroup(of: (Int, ProviderUsage).self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask {
                    let usage = await self.fetchSafely(provider)
                    return (index, usage)
                }
            }

            var ordered = providers.map { ProviderUsage.placeholder(for: $0.kind) }
            for await (index, usage) in group {
                ordered[index] = usage
            }
            return ordered
        }
    }

    private func fetchSafely(_ provider: any UsageProviding) async -> ProviderUsage {
        // Providers catch their own network failures; this is a last-resort shield.
        let usage = await provider.fetchUsage()
        return usage
    }
}
