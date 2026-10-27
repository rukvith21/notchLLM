import Foundation

/// Placeholder Cursor adapter. Phase 3 wires local / account usage.
struct CursorUsageProvider: UsageProviding {
    let kind: ProviderKind = .cursor

    func fetchUsage() async -> ProviderUsage {
        // TODO(Phase 3): read Cursor usage remaining.
        ProviderUsage.placeholder(for: .cursor)
    }
}
