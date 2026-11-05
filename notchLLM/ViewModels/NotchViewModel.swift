import Foundation
import Observation

/// Drives the notch pill. Observes settings changes and optional auto-refresh timer.
@MainActor
@Observable
final class NotchViewModel {
    private(set) var usages: [ProviderUsage]
    private(set) var isRefreshing = false
    private(set) var lastError: String?
    private(set) var lastRefreshedAt: Date?
    private(set) var autoRefreshSeconds: Int = 60

    var isExpanded = false
    var focusedProvider: ProviderKind?

    private let aggregator: UsageAggregator
    private let settingsStore: any SettingsStoring
    /// Stored as nonisolated so `deinit` can clear it without MainActor hops.
    nonisolated(unsafe) private var settingsObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?
    private var hasCompletedInitialLoad = false
    var onRefreshCycleCompleted: (() -> Void)?

    init(
        aggregator: UsageAggregator = UsageAggregator(),
        settingsStore: any SettingsStoring = FileSettingsStore.shared
    ) {
        self.aggregator = aggregator
        self.settingsStore = settingsStore
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
                await self?.reloadAutoRefreshPreference()
                await self?.refresh()
            }
        }
        Task { await reloadAutoRefreshPreference() }
    }

    func stopObservingSettingsChanges() {
        refreshTask?.cancel()
        refreshTask = nil
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
            self.settingsObserver = nil
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer {
            isRefreshing = false
            onRefreshCycleCompleted?()
        }

        // Only flash loading skeletons on the first load — quiet auto-refresh keeps last rings.
        if !hasCompletedInitialLoad {
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
        }

        let next = await aggregator.refreshAll()
        usages = next
        lastRefreshedAt = Date()
        hasCompletedInitialLoad = true
        if let firstError = next.first(where: {
            if case .error = $0.status { return true }
            return false
        }) {
            lastError = firstError.detail
        }
        scheduleAutoRefresh()
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

    var lastRefreshedLabel: String {
        guard let lastRefreshedAt else { return "Never refreshed" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastRefreshedAt, relativeTo: Date()))"
    }

    var autoRefreshLabel: String {
        if autoRefreshSeconds <= 0 { return "Auto-refresh off" }
        if autoRefreshSeconds < 60 { return "Auto-refresh \(autoRefreshSeconds)s" }
        let minutes = autoRefreshSeconds / 60
        return "Auto-refresh \(minutes)m"
    }

    // MARK: - Auto-refresh

    private func reloadAutoRefreshPreference() async {
        let settings = await settingsStore.load()
        autoRefreshSeconds = max(settings.autoRefreshSeconds, 0)
        scheduleAutoRefresh()
    }

    private func scheduleAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        let seconds = autoRefreshSeconds
        guard seconds > 0 else { return }
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }
}
