import Foundation

/// Snapshot of remaining / used quota for a single provider.
struct ProviderUsage: Identifiable, Equatable, Sendable {
    let provider: ProviderKind
    /// 0...1 fraction of quota consumed. `nil` when unknown / unavailable.
    let usedFraction: Double?
    let tokensUsed: Int?
    let tokensLimit: Int?
    /// When the quota window resets. `nil` if unknown.
    let resetsAt: Date?
    let status: UsageStatus
    let detail: String?

    var id: ProviderKind { provider }

    enum UsageStatus: Equatable, Sendable {
        case ready
        case loading
        case unavailable
        case error(String)
    }

    var percentUsedDisplay: String {
        guard let usedFraction else { return "—" }
        return "\(Int((usedFraction * 100).rounded()))%"
    }

    var tokensUsedDisplay: String {
        guard let tokensUsed, let tokensLimit else {
            return detail ?? "No quota data"
        }
        return "\(Self.formatCount(tokensUsed)) / \(Self.formatCount(tokensLimit))"
    }

    var tokensLeftDisplay: String {
        guard let tokensUsed, let tokensLimit else { return "—" }
        return Self.formatCount(max(tokensLimit - tokensUsed, 0)) + " left"
    }

    var resetDisplay: String {
        guard let resetsAt else { return "Reset unknown" }
        let remaining = resetsAt.timeIntervalSinceNow
        if remaining <= 0 { return "Resetting…" }
        return "Resets in \(Self.formatDuration(remaining))"
    }

    static func placeholder(for provider: ProviderKind) -> ProviderUsage {
        ProviderUsage(
            provider: provider,
            usedFraction: nil,
            tokensUsed: nil,
            tokensLimit: nil,
            resetsAt: nil,
            status: .unavailable,
            detail: "Adapter not connected"
        )
    }

    /// Demo snapshot used by Phase-2 stubs until live adapters land.
    static func mock(
        for provider: ProviderKind,
        usedFraction: Double,
        tokensUsed: Int,
        tokensLimit: Int,
        resetsIn: TimeInterval,
        detail: String? = nil
    ) -> ProviderUsage {
        ProviderUsage(
            provider: provider,
            usedFraction: min(max(usedFraction, 0), 1),
            tokensUsed: tokensUsed,
            tokensLimit: tokensLimit,
            resetsAt: Date().addingTimeInterval(resetsIn),
            status: .ready,
            detail: detail
        )
    }

    private static func formatCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(minutes, 1))m"
    }
}
