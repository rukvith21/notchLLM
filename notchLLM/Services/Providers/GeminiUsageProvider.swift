import Foundation

/// Gemini adapter — prefers live Cloud Code quota, never login-loops.
///
/// Auth / data order:
/// 1. Local Gemini MacOS / Antigravity session files (auth signal)
/// 2. Jetski / Gemini CLI OAuth → `retrieveUserQuotaSummary` / `retrieveUserQuota`
/// 3. API key validation + manual window
/// 4. Manual caps / demo mock
struct GeminiUsageProvider: UsageProviding {
    let kind: ProviderKind = .gemini

    private let credentials: CredentialStore
    private let settingsStore: any SettingsStoring
    private let sessionDetector: GeminiSessionDetector
    private let oauthStore: GeminiOAuthStore
    private let http: AsyncHTTPClient

    init(
        credentials: CredentialStore = .shared,
        settingsStore: any SettingsStoring = FileSettingsStore.shared,
        sessionDetector: GeminiSessionDetector = GeminiSessionDetector(),
        oauthStore: GeminiOAuthStore = GeminiOAuthStore(),
        http: AsyncHTTPClient = .shared
    ) {
        self.credentials = credentials
        self.settingsStore = settingsStore
        self.sessionDetector = sessionDetector
        self.oauthStore = oauthStore
        self.http = http
    }

    func fetchUsage() async -> ProviderUsage {
        let settings = await settingsStore.load()
        let manual = settings.config(for: .gemini)
        let session = sessionDetector.detect()
        let apiKey = await credentials.geminiAPIKey()

        // Live OAuth quota first when tokens exist — never prompts for login.
        if let oauth = await oauthStore.resolveAccessToken(),
           let live = await fetchLiveQuota(accessToken: oauth.accessToken, manual: manual, oauthSource: oauth.source) {
            return live
        }

        if session.isAuthenticated {
            return await resolveAuthenticatedLocal(
                session: session,
                apiKey: apiKey,
                manual: manual
            )
        }

        if let apiKey {
            return await resolveAPIKey(apiKey: apiKey, manual: manual)
        }

        if settings.manualFallbackEnabled, manual.windowLimit > 0 {
            return .manual(
                for: .gemini,
                used: manual.windowUsed,
                limit: manual.windowLimit,
                resetsAt: manual.windowResetsAt ?? endOfLocalDay(),
                authState: .manualOnly,
                detail: "Manual \(manual.tier) cap · no Gemini session/key found"
            )
        }

        if settings.preferMockWhenUnauthenticated {
            return .mock(
                for: .gemini,
                usedFraction: 0.68,
                tokensUsed: 680_000,
                tokensLimit: 1_000_000,
                resetsIn: 4 * 3_600,
                detail: "Demo mock · add GEMINI_API_KEY or use Gemini app session",
                authState: .unauthenticated
            )
        }

        return ProviderUsage(
            provider: .gemini,
            usedFraction: nil,
            tokensUsed: nil,
            tokensLimit: nil,
            resetsAt: nil,
            status: .unavailable,
            source: .degraded,
            authState: .unauthenticated,
            detail: "No Gemini session, API key, or manual cap"
        )
    }

    // MARK: - Live Cloud Code quota

    private func fetchLiveQuota(
        accessToken: String,
        manual: ProviderManualConfig,
        oauthSource: String
    ) async -> ProviderUsage? {
        let headers = [
            "Authorization": "Bearer \(accessToken)",
            "Content-Type": "application/json",
            "User-Agent": "antigravity/1.11.3 Darwin/arm64",
            "Accept": "application/json"
        ]
        let endpoints = [
            "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
            "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
            "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
        ]

        for candidate in endpoints {
            guard let url = URL(string: candidate) else { continue }
            do {
                let (data, response) = try await http.postJSON(
                    url: url,
                    headers: headers,
                    body: Data("{}".utf8)
                )
                guard (200..<300).contains(response.statusCode),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let parsed = parseQuotaJSON(json, manual: manual, oauthSource: oauthSource)
                else { continue }
                return parsed
            } catch {
                continue
            }
        }
        return nil
    }

    private func parseQuotaJSON(
        _ json: [String: Any],
        manual: ProviderManualConfig,
        oauthSource: String
    ) -> ProviderUsage? {
        var remainingSamples: [(fraction: Double, reset: Date?)] = []

        if let groups = json["groups"] as? [[String: Any]] {
            for group in groups {
                let buckets = group["buckets"] as? [[String: Any]] ?? []
                for bucket in buckets {
                    if let remaining = number(bucket["remainingFraction"]) {
                        remainingSamples.append((remaining, isoDate(bucket["resetTime"])))
                    }
                }
            }
        }

        if let buckets = json["buckets"] as? [[String: Any]] {
            for bucket in buckets {
                // Prefer Gemini model buckets when present.
                let model = (bucket["modelId"] as? String)?.lowercased() ?? ""
                let isGemini = model.contains("gemini") || model.isEmpty
                if let remaining = number(bucket["remainingFraction"]), isGemini || remainingSamples.isEmpty {
                    remainingSamples.append((remaining, isoDate(bucket["resetTime"])))
                }
            }
        }

        guard let tightest = remainingSamples.min(by: { $0.fraction < $1.fraction }) else {
            return nil
        }

        let remaining = min(max(tightest.fraction, 0), 1)
        let usedFraction = 1 - remaining
        let limit = max(manual.windowLimit, 1_000)
        let used = Int((usedFraction * Double(limit)).rounded())

        return ProviderUsage(
            provider: .gemini,
            usedFraction: usedFraction,
            tokensUsed: used,
            tokensLimit: limit,
            resetsAt: tightest.reset ?? manual.windowResetsAt ?? endOfLocalDay(),
            status: .ready,
            source: .live,
            authState: .authenticated,
            detail: "Gemini live quota (\(oauthSource)) · \(Int((remaining * 100).rounded()))% left"
        )
    }

    // MARK: - Local / key paths

    private func resolveAuthenticatedLocal(
        session: GeminiSessionDetector.Snapshot,
        apiKey: String?,
        manual: ProviderManualConfig
    ) async -> ProviderUsage {
        let users = session.authFilesPresent.joined(separator: ",")
        let baseDetail = "Local Gemini session (\(users.isEmpty ? "active" : users))"

        if let apiKey {
            let keyOK = await validateGeminiAPIKey(apiKey)
            if keyOK {
                return compose(
                    manual: manual,
                    source: .apiKeyValidated,
                    authState: .authenticated,
                    detail: "\(baseDetail) · API key OK · manual tracking"
                )
            }
        }

        return compose(
            manual: manual,
            source: .localSession,
            authState: .authenticated,
            detail: "\(baseDetail) · manual/local tracking (no login needed)"
        )
    }

    private func resolveAPIKey(apiKey: String, manual: ProviderManualConfig) async -> ProviderUsage {
        let keyOK = await validateGeminiAPIKey(apiKey)
        if keyOK {
            return compose(
                manual: manual,
                source: .apiKeyValidated,
                authState: .apiKeyPresent,
                detail: "Gemini API key valid · \(manual.tier) manual window"
            )
        }

        return compose(
            manual: manual,
            source: .degraded,
            authState: .apiKeyPresent,
            detail: "Gemini API key present · probe failed · using manual cap"
        )
    }

    private func compose(
        manual: ProviderManualConfig,
        source: UsageSource,
        authState: ProviderAuthState,
        detail: String
    ) -> ProviderUsage {
        let limit = max(manual.windowLimit, 1)
        let used = max(manual.windowUsed, 0)
        return ProviderUsage(
            provider: .gemini,
            usedFraction: min(Double(used) / Double(limit), 1),
            tokensUsed: used,
            tokensLimit: limit,
            resetsAt: manual.windowResetsAt ?? endOfLocalDay(),
            status: .ready,
            source: source,
            authState: authState,
            detail: detail
        )
    }

    private func validateGeminiAPIKey(_ apiKey: String) async -> Bool {
        guard var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
            return false
        }
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "pageSize", value: "1")
        ]
        guard let url = components.url else { return false }

        do {
            let (_, response) = try await http.getJSON(url: url)
            return (200..<300).contains(response.statusCode)
        } catch {
            return false
        }
    }

    private func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }

    private func isoDate(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let basic = ISO8601DateFormatter()
        return iso.date(from: text) ?? basic.date(from: text)
    }

    private func endOfLocalDay() -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: 1, to: start) ?? Date().addingTimeInterval(86_400)
    }
}
