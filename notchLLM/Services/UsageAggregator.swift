import Foundation

/// Phase-1 stub aggregator — fans out to provider stubs without network I/O.
actor UsageAggregator: UsageAggregating {
    private let providers: [any UsageProviding]

    init(providers: [any UsageProviding]? = nil) {
        self.providers = providers ?? [
            GeminiUsageProvider(),
            ChatGPTUsageProvider(),
            CursorUsageProvider()
        ]
    }

    func refreshAll() async -> [ProviderUsage] {
        var results: [ProviderUsage] = []
        results.reserveCapacity(providers.count)
        for provider in providers {
            results.append(await provider.fetchUsage())
        }
        return results
    }
}
