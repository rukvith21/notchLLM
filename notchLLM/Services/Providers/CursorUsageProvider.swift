import Foundation

/// Cursor IDE adapter — decrypts local session tokens and hits the live dashboard APIs.
///
/// Live order (first success wins):
/// 1. `POST https://cursor.com/api/dashboard/get-current-period-usage` (Workos cookie + Origin)
/// 2. `GET  https://cursor.com/api/usage-summary`
/// 3. Legacy bearer `/api/usage` endpoints
/// 4. Membership + real manual window (never invented stubs)
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
            if let token = session.accessToken,
               let live = await fetchLiveUsage(token: token, manual: manual, session: session) {
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

    // MARK: - Live

    private func fetchLiveUsage(
        token: String,
        manual: ProviderManualConfig,
        session: CursorSessionDetector.Snapshot
    ) async -> ProviderUsage? {
        if let dashboard = await fetchDashboardPeriodUsage(token: token, manual: manual, session: session) {
            return dashboard
        }
        if let summary = await fetchUsageSummary(token: token, manual: manual, session: session) {
            return summary
        }
        return await fetchLegacyBearerUsage(token: token, manual: manual, session: session)
    }

    private func fetchDashboardPeriodUsage(
        token: String,
        manual: ProviderManualConfig,
        session: CursorSessionDetector.Snapshot
    ) async -> ProviderUsage? {
        guard let url = URL(string: "https://cursor.com/api/dashboard/get-current-period-usage") else {
            return nil
        }
        for cookie in workosCookies(token: token, authID: session.authID) {
            let headers = [
                "Cookie": cookie,
                "Origin": "https://cursor.com",
                "Referer": "https://cursor.com/dashboard",
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": "Mozilla/5.0"
            ]
            do {
                let (data, response) = try await http.postJSON(url: url, headers: headers, body: Data("{}".utf8))
                guard (200..<300).contains(response.statusCode),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let parsed = parseDashboardJSON(json, manual: manual, session: session)
                else { continue }
                return parsed
            } catch {
                continue
            }
        }
        return nil
    }

    private func fetchUsageSummary(
        token: String,
        manual: ProviderManualConfig,
        session: CursorSessionDetector.Snapshot
    ) async -> ProviderUsage? {
        let urls = [
            "https://cursor.com/api/usage-summary",
            "https://www.cursor.com/api/usage-summary"
        ]
        for candidate in urls {
            guard let url = URL(string: candidate) else { continue }
            for cookie in workosCookies(token: token, authID: session.authID) {
                let headers = [
                    "Cookie": cookie,
                    "Origin": "https://cursor.com",
                    "Referer": "https://cursor.com/dashboard",
                    "Accept": "application/json",
                    "User-Agent": "Mozilla/5.0"
                ]
                do {
                    let (data, response) = try await http.getJSON(url: url, headers: headers)
                    guard (200..<300).contains(response.statusCode),
                          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let parsed = parseUsageJSON(json, manual: manual, session: session)
                    else { continue }
                    return parsed
                } catch {
                    continue
                }
            }
        }
        return nil
    }

    private func fetchLegacyBearerUsage(
        token: String,
        manual: ProviderManualConfig,
        session: CursorSessionDetector.Snapshot
    ) async -> ProviderUsage? {
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
                guard (200..<300).contains(response.statusCode),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let parsed = parseUsageJSON(json, manual: manual, session: session)
                else { continue }
                return parsed
            } catch {
                continue
            }
        }
        return nil
    }

    private func workosCookies(token: String, authID: String?) -> [String] {
        var userIDs: [String] = []
        if let authID, !authID.isEmpty {
            userIDs.append(authID)
            if let pipe = authID.split(separator: "|").last {
                userIDs.append(String(pipe))
            }
        }
        if let sub = jwtSubject(token) {
            userIDs.append(sub)
            if let pipe = sub.split(separator: "|").last {
                userIDs.append(String(pipe))
            }
        }
        var seen = Set<String>()
        var cookies: [String] = []
        for uid in userIDs where seen.insert(uid).inserted {
            let raw = "\(uid)::\(token)"
            let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
            cookies.append("WorkosCursorSessionToken=\(encoded)")
            // Explicit %3A%3A form used by several open-source clients.
            let uidEnc = uid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uid
            let tokEnc = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
            cookies.append("WorkosCursorSessionToken=\(uidEnc)%3A%3A\(tokEnc)")
        }
        return cookies
    }

    private func jwtSubject(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        let pad = (4 - payload.count % 4) % 4
        payload += String(repeating: "=", count: pad)
        guard let data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String,
              !sub.isEmpty
        else { return nil }
        return sub
    }

    private func parseDashboardJSON(
        _ json: [String: Any],
        manual: ProviderManualConfig,
        session: CursorSessionDetector.Snapshot
    ) -> ProviderUsage? {
        let planUsage = json["planUsage"] as? [String: Any]
        let percent = number(planUsage?["totalPercentUsed"])
            ?? number(planUsage?["apiPercentUsed"])
            ?? number(planUsage?["autoPercentUsed"])
        let totalSpend = number(planUsage?["totalSpend"])
        let limit = number(planUsage?["limit"])
        let included = number(planUsage?["includedSpend"])

        var usedFraction: Double?
        if let percent {
            usedFraction = percent > 1 ? min(percent / 100, 1) : min(max(percent, 0), 1)
        } else if let totalSpend, let limit, limit > 0 {
            usedFraction = min(totalSpend / limit, 1)
        }
        guard let usedFraction else { return nil }

        let safeLimit = Int(limit ?? included ?? Double(max(manual.windowLimit, membershipDefaultLimit(session.membershipType))))
        let safeUsed = Int((usedFraction * Double(max(safeLimit, 1))).rounded())
        let resets = millisOrISODate(json["billingCycleEnd"]) ?? manual.windowResetsAt ?? endOfLocalMonth()
        let plan = session.membershipType ?? manual.tier

        return ProviderUsage(
            provider: .cursor,
            usedFraction: usedFraction,
            tokensUsed: safeUsed,
            tokensLimit: max(safeLimit, 1),
            resetsAt: resets,
            status: .ready,
            source: .live,
            authState: .authenticated,
            detail: "Cursor \(plan) · live dashboard · \(Int((1 - usedFraction) * 100))% left"
        )
    }

    private func parseUsageJSON(
        _ json: [String: Any],
        manual: ProviderManualConfig,
        session: CursorSessionDetector.Snapshot
    ) -> ProviderUsage? {
        if let dashboard = parseDashboardJSON(json, manual: manual, session: session) {
            return dashboard
        }

        let used = deepestInt(json, keys: [
            "numRequests", "used", "requestsUsed", "totalRequests", "apiPercentUsed",
            "premiumRequests", "numRequestsTotal"
        ])
        let limit = deepestInt(json, keys: [
            "maxRequestUsage", "limit", "requestsLimit", "totalLimit", "maxRequests",
            "premiumRequestLimit"
        ])

        if used == nil, limit == nil,
           let pct = deepestDouble(json, keys: ["usagePct", "percentUsed", "pctUsed", "apiPercentUsed", "totalPercentUsed"]) {
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

    private func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }

    private func millisOrISODate(_ value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            // Cursor often returns epoch millis as a string/number.
            if raw > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: raw / 1000)
            }
            if raw > 1_000_000_000 {
                return Date(timeIntervalSince1970: raw)
            }
        }
        if let text = value as? String {
            if let asDouble = Double(text) {
                return millisOrISODate(NSNumber(value: asDouble))
            }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let basic = ISO8601DateFormatter()
            return iso.date(from: text) ?? basic.date(from: text)
        }
        return nil
    }

    private func deepestInt(_ json: [String: Any], keys: [String], depth: Int = 0) -> Int? {
        guard depth < 4 else { return nil }
        for key in keys {
            if let number = json[key] as? NSNumber { return number.intValue }
            if let text = json[key] as? String, let value = Int(text) { return value }
        }
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
        for key in keys {
            if let date = millisOrISODate(json[key]) { return date }
            if let nested = json[key] as? [String: Any], let date = millisOrISODate(nested["iso"]) {
                return date
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
