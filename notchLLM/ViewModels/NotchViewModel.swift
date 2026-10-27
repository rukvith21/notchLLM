import Foundation
import Observation

/// Drives the notch pill. Observes settings changes so rings refresh without restart.
@MainActor
@Observable
final class NotchViewModel {
    private(set) var usages: [ProviderUsage]
    private(set) var isRefreshing = false
    private(set) var lastError: String?

    var isExpanded = false
    var focusedProvider: ProviderKind?

    private let aggregator: UsageAggregator
    /// Stored as nonisolated so `deinit` can clear it without MainActor hops.
    nonisolated(unsafe) private var settingsObserver: NSObjectProtocol?

    init(aggregator: UsageAggregator = UsageAggregator()) {
        self.aggregator = aggregator
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

    func startObservingSettingsChanges() {
        guard settingsObserver == nil else { return }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .notchLLMSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func stopObservingSettingsChanges() {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
            self.settingsObserver = nil
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

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }
}
