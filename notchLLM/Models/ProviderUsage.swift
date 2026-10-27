import Foundation

/// Snapshot of remaining / used quota for a single provider.
struct ProviderUsage: Identifiable, Equatable, Sendable {
    let provider: ProviderKind
    /// 0...1 fraction of quota consumed. `nil` when unknown / unavailable.
    let usedFraction: Double?
    let status: UsageStatus
    let detail: String?

    var id: ProviderKind { provider }

    enum UsageStatus: Equatable, Sendable {
        case ready
        case loading
        case unavailable
        case error(String)
    }

    static func placeholder(for provider: ProviderKind) -> ProviderUsage {
        ProviderUsage(
            provider: provider,
            usedFraction: nil,
            status: .unavailable,
            detail: "Adapter not connected"
        )
    }
}
