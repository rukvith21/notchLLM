import Foundation
import Observation

/// Drives the notch pill. Phase 2 adds hover expansion + mock-backed rings;
/// Phase 3 swaps stubs for live adapters.
@MainActor
@Observable
final class NotchViewModel {
    private(set) var usages: [ProviderUsage]
    private(set) var isRefreshing = false
    private(set) var lastError: String?

    /// Pill hover / detail expansion state (UI only).
    var isExpanded = false
    var focusedProvider: ProviderKind?

    private let aggregator: UsageAggregator

    init(aggregator: UsageAggregator = UsageAggregator()) {
        self.aggregator = aggregator
        // Seed with mock-ready placeholders so first paint isn't empty.
        self.usages = [
            .mock(for: .gemini, usedFraction: 0.68, tokensUsed: 680_000, tokensLimit: 1_000_000, resetsIn: 4 * 3_600),
            .mock(for: .chatGPT, usedFraction: 0.42, tokensUsed: 42_000, tokensLimit: 100_000, resetsIn: 2 * 86_400),
            .mock(for: .cursor, usedFraction: 0.81, tokensUsed: 405, tokensLimit: 500, resetsIn: 12 * 3_600)
        ]
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        usages = usages.map {
            ProviderUsage(
                provider: $0.provider,
                usedFraction: $0.usedFraction,
                tokensUsed: $0.tokensUsed,
                tokensLimit: $0.tokensLimit,
                resetsAt: $0.resetsAt,
                status: .loading,
                detail: $0.detail
            )
        }

        let next = await aggregator.refreshAll()
        usages = next
    }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        if !expanded {
            focusedProvider = nil
        }
    }

    func focus(_ provider: ProviderKind?) {
        focusedProvider = provider
        if provider != nil {
            isExpanded = true
        }
    }
}
