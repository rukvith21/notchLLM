import Foundation

/// Placeholder Cursor adapter. Phase 3 wires local / account usage.
/// Phase 2 returns stable mock usage so the pill UI is demoable.
struct CursorUsageProvider: UsageProviding {
    let kind: ProviderKind = .cursor

    func fetchUsage() async -> ProviderUsage {
        // TODO(Phase 3): read Cursor usage remaining.
        try? await Task.sleep(for: .milliseconds(70))
        return .mock(
            for: .cursor,
            usedFraction: 0.81,
            tokensUsed: 405,
            tokensLimit: 500,
            resetsIn: 12 * 3_600 + 40 * 60,
            detail: "Mock Cursor fast requests"
        )
    }
}
