import Foundation

/// Cursor IDE adapter (best-effort).
///
/// Assumptions:
/// - Auth lives in Cursor `state.vscdb` (`cursorAuth/*`)
/// - Membership keys (`stripeMembershipType`, `stripeSubscriptionStatus`) are safe to surface
/// - Optional live usage: `GET https://cursor.com/api/usage` with Bearer access token
///   (endpoint/shape may change; failures degrade to manual/membership estimate)
struct CursorUsageProvider: UsageProviding {
    let kind: ProviderKind = .cursor

    private let credentials: CredentialStore
    private let settingsStore: any SettingsStoring
    private let sessionDetector: CursorSessionDetector
    private let http: AsyncHTTPClient

    init(
        credentials: CredentialStore = .shared,
        settingsStore: any SettingsStoring = FileSettingsStore.shared,
        sessionDetector: CursorSessionDetector = CursorSessionDetector(),
        http: AsyncHTTPClient = .shared
    ) {
        self.credentials = credentials
        self.settingsStore = settingsStore
        self.sessionDetector = sessionDetector
        self.http = http
    }

    func fetchUsage() async -> ProviderUsage {
        let settings = await settingsStore.load()
        let manual = settings.config(for: .cursor)
        let session = sessionDetector.detect()
        let apiKey = await credentials.cursorAPIKey()

        if session.isSignedIn {
            if let token = session.accessToken, let live = await fetchLiveUsage(token: token, manual: manual, session: session) {
                return live
            }

            let limit = max(manual.windowLimit, membershipDefaultLimit(session.membershipType))
            let used = max(manual.windowUsed, 0)
            let plan = session.membershipType ?? manual.tier
            let status = session.subscriptionStatus ?? "unknown"
            return ProviderUsage(
                provider: .cursor,
                usedFraction: min(Double(used) / Double(limit), 1),
                tokensUsed: used,
                tokensLimit: limit,
                resetsAt: manual.windowResetsAt ?? endOfLocalMonth(),
                status: .ready,
                source: .localSession,
                authState: .authenticated,
                detail: "Cursor \(plan) (\(status)) · \(session.email ?? "signed in") · manual window"
            )
        }

        if apiKey != nil, settings.manualFallbackEnabled || manual.windowLimit > 0 {
            return .manual(
                for: .cursor,
                used: max(manual.windowUsed, 0),
                limit: max(manual.windowLimit, 1),
                resetsAt: manual.windowResetsAt ?? endOfLocalMonth(),
                authState: .apiKeyPresent,
                detail: "CURSOR_API_KEY present · live usage unavailable · manual cap"
            )
        }

        if settings.manualFallbackEnabled, manual.windowLimit > 0 {
            return .manual(
                for: .cursor,
                used: manual.windowUsed,
                limit: manual.windowLimit,
                resetsAt: manual.windowResetsAt ?? endOfLocalMonth(),
                authState: .manualOnly,
                detail: "Manual \(manual.tier) cap · no Cursor session"
            )
        }

        if settings.preferMockWhenUnauthenticated {
            return .mock(
                for: .cursor,
                usedFraction: 0.81,
                tokensUsed: 405,
                tokensLimit: 500,
                resetsIn: 12 * 3_600,
                detail: "Demo mock · open Cursor while signed in for local session",
                authState: .unauthenticated
            )
        }

        return ProviderUsage(
            provider: .cursor,
            usedFraction: nil,
            tokensUsed: nil,
            tokensLimit: nil,
            resetsAt: nil,
            status: .unavailable,
            source: .degraded,
            authState: .unauthenticated,
            detail: "No Cursor session in state.vscdb"
        )
    }

    private func fetchLiveUsage(
        token: String,
        manual: ProviderManualConfig,
        session: CursorSessionDetector.Snapshot
    ) async -> ProviderUsage? {
        // Best-effort endpoints; ignore non-2xx / parse failures (no login loop).
        let candidates = [
            "https://cursor.com/api/usage",
            "https://www.cursor.com/api/usage",
            "https://api2.cursor.sh/auth/usage"
        ]
        let headers = [
            "Authorization": "Bearer \(token)",
            "Accept": "application/json"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            do {
                let (data, response) = try await http.getJSON(url: url, headers: headers)
                guard (200..<300).contains(response.statusCode) else { continue }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                if let parsed = parseUsageJSON(json, manual: manual, session: session) {
                    return parsed
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func parseUsageJSON(
        _ json: [String: Any],
        manual: ProviderManualConfig,
        session: CursorSessionDetector.Snapshot
    ) -> ProviderUsage? {
        let used = deepestInt(json, keys: [
            "numRequests", "used", "requestsUsed", "totalRequests", "apiPercentUsed",
            "premiumRequests", "numRequestsTotal"
        ])
        let limit = deepestInt(json, keys: [
            "maxRequestUsage", "limit", "requestsLimit", "totalLimit", "maxRequests",
            "premiumRequestLimit"
        ])

        // Percent-only payloads (0...100 or 0...1).
        if used == nil, limit == nil,
           let pct = deepestDouble(json, keys: ["usagePct", "percentUsed", "pctUsed", "apiPercentUsed"]) {
            let fraction = pct > 1 ? min(pct / 100, 1) : min(max(pct, 0), 1)
            let fallbackLimit = max(manual.windowLimit, membershipDefaultLimit(session.membershipType))
            let derivedUsed = Int((fraction * Double(fallbackLimit)).rounded())
            return ProviderUsage(
                provider: .cursor,
                usedFraction: fraction,
                tokensUsed: derivedUsed,
                tokensLimit: fallbackLimit,
                resetsAt: dateValue(json) ?? manual.windowResetsAt ?? endOfLocalMonth(),
                status: .ready,
                source: .live,
                authState: .authenticated,
                detail: "Cursor live usage · \(session.membershipType ?? "plan")"
            )
        }

        guard used != nil || limit != nil else { return nil }

        let safeLimit = max(limit ?? max(manual.windowLimit, membershipDefaultLimit(session.membershipType)), 1)
        let safeUsed = max(used ?? manual.windowUsed, 0)
        return ProviderUsage(
            provider: .cursor,
            usedFraction: min(Double(safeUsed) / Double(safeLimit), 1),
            tokensUsed: safeUsed,
            tokensLimit: safeLimit,
            resetsAt: dateValue(json) ?? manual.windowResetsAt ?? endOfLocalMonth(),
            status: .ready,
            source: .live,
            authState: .authenticated,
            detail: "Cursor live usage · \(session.membershipType ?? "plan")"
        )
    }

    private func deepestInt(_ json: [String: Any], keys: [String], depth: Int = 0) -> Int? {
        guard depth < 4 else { return nil }
        for key in keys {
            if let number = json[key] as? NSNumber { return number.intValue }
            if let text = json[key] as? String, let value = Int(text) { return value }
        }
        for key in keys {
            if let nested = json[key] as? [String: Any],
               let found = deepestInt(nested, keys: keys, depth: depth + 1) {
                return found
            }
        }
        // Model-keyed nests ("gpt-4", "default", …)
        for (_, value) in json {
            if let nested = value as? [String: Any],
               let found = deepestInt(nested, keys: keys, depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    private func deepestDouble(_ json: [String: Any], keys: [String], depth: Int = 0) -> Double? {
        guard depth < 4 else { return nil }
        for key in keys {
            if let number = json[key] as? NSNumber { return number.doubleValue }
            if let text = json[key] as? String, let value = Double(text) { return value }
        }
        for (_, value) in json {
            if let nested = value as? [String: Any],
               let found = deepestDouble(nested, keys: keys, depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    private func dateValue(_ json: [String: Any]) -> Date? {
        let keys = ["startOfMonth", "resetDate", "resetsAt", "billingCycleEnd"]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        for key in keys {
            if let text = json[key] as? String {
                if let date = iso.date(from: text) ?? isoBasic.date(from: text) {
                    return date
                }
            }
            if let nested = json[key] as? [String: Any], let text = nested["iso"] as? String {
                if let date = iso.date(from: text) ?? isoBasic.date(from: text) {
                    return date
                }
            }
        }
        return nil
    }

    private func membershipDefaultLimit(_ membership: String?) -> Int {
        switch membership?.lowercased() {
        case "pro", "pro_plus", "pro+": 500
        case "business", "team", "enterprise": 1000
        case "free", "hobby": 50
        default: 500
        }
    }

    private func endOfLocalMonth() -> Date {
        let calendar = Calendar.current
        let now = Date()
        guard let interval = calendar.dateInterval(of: .month, for: now) else {
            return now.addingTimeInterval(30 * 86_400)
        }
        return interval.end
    }
}
