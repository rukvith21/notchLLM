import Foundation
import Observation

/// Drives the notch pill. Phase 3 wires real adapters (async, off main UI work).
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
        // Neutral loading seed — refresh() fills real/mock data immediately.
        self.usages = ProviderKind.allCases.map { kind in
            ProviderUsage(
                provider: kind,
                usedFraction: nil,
                tokensUsed: nil,
                tokensLimit: nil,
                resetsAt: nil,
                status: .loading,
                source: .degraded,
                authState: .unauthenticated,
                detail: "Loading…"
            )
        }
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
                source: $0.source,
                authState: $0.authState,
                detail: $0.detail
            )
        }

        // Aggregator is an actor — hop off MainActor for the await.
        let next = await aggregator.refreshAll()
        usages = next
        if let firstError = next.first(where: {
            if case .error = $0.status { return true }
            return false
        }) {
            lastError = firstError.detail
        }
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
