import Foundation

/// Contract for a single-provider usage adapter.
protocol UsageProviding: Sendable {
    var kind: ProviderKind { get }
    func fetchUsage() async -> ProviderUsage
}

/// Aggregates multiple providers into a single refreshable snapshot.
protocol UsageAggregating: Sendable {
    func refreshAll() async -> [ProviderUsage]
}
