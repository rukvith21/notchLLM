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
            let used = manual.windowUsed > 0 ? manual.windowUsed : Int(Double(limit) * 0.55)
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
                detail: "Cursor \(plan) (\(status)) · \(session.email ?? "signed in") · manual estimate"
            )
        }

        if apiKey != nil {
            return .manual(
                for: .cursor,
                used: manual.windowUsed > 0 ? manual.windowUsed : Int(Double(max(manual.windowLimit, 1)) * 0.4),
                limit: max(manual.windowLimit, 1),
                resetsAt: manual.windowResetsAt ?? endOfLocalMonth(),
                authState: .apiKeyPresent,
                detail: "CURSOR_API_KEY present · live usage not wired · manual cap"
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
        // Best-effort; ignore non-2xx / parse failures.
        guard let url = URL(string: "https://cursor.com/api/usage") else { return nil }
        do {
            let (data, response) = try await http.getJSON(
                url: url,
                headers: [
                    "Authorization": "Bearer \(token)",
                    "Accept": "application/json"
                ]
            )
            guard (200..<300).contains(response.statusCode) else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            // Tolerant parse across known shapes.
            let used = intValue(json, keys: ["numRequests", "used", "requestsUsed", "totalRequests"])
                ?? manual.windowUsed
            let limit = intValue(json, keys: ["maxRequestUsage", "limit", "requestsLimit", "totalLimit"])
                ?? max(manual.windowLimit, membershipDefaultLimit(session.membershipType))
            let safeLimit = max(limit, 1)
            let safeUsed = max(used, 0)

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
        } catch {
            return nil
        }
    }

    private func intValue(_ json: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let number = json[key] as? NSNumber { return number.intValue }
            if let nested = json[key] as? [String: Any] {
                if let n = nested["used"] as? NSNumber { return n.intValue }
                if let n = nested["numRequests"] as? NSNumber { return n.intValue }
            }
        }
        // Some payloads nest under "gpt-4" / model keys
        for (_, value) in json {
            if let nested = value as? [String: Any],
               let n = nested["numRequests"] as? NSNumber {
                return n.intValue
            }
        }
        return nil
    }

    private func dateValue(_ json: [String: Any]) -> Date? {
        let keys = ["startOfMonth", "resetDate", "resetsAt"]
        for key in keys {
            if let text = json[key] as? String {
                let iso = ISO8601DateFormatter()
                if let date = iso.date(from: text) { return date }
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
