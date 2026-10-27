import Foundation
import Observation

/// Drives the notch pill. Phase 1 shows placeholder provider cells;
/// Phase 2–3 wire live refresh + real adapters.
@MainActor
@Observable
final class NotchViewModel {
    private(set) var usages: [ProviderUsage]
    private(set) var isRefreshing = false
    private(set) var lastError: String?

    private let aggregator: UsageAggregator

    init(aggregator: UsageAggregator = UsageAggregator()) {
        self.aggregator = aggregator
        self.usages = ProviderKind.allCases.map { ProviderUsage.placeholder(for: $0) }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        // Optimistic loading markers (UI-friendly).
        usages = usages.map {
            ProviderUsage(
                provider: $0.provider,
                usedFraction: $0.usedFraction,
                status: .loading,
                detail: $0.detail
            )
        }

        let next = await aggregator.refreshAll()
        usages = next
    }
}
