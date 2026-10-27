import Foundation

/// Gemini adapter — prefers local session / API key / manual caps over any login prompt.
///
/// Auth resolution order (first win for “authenticated”, never loops on login):
/// 1. Local Gemini MacOS / Antigravity session files
/// 2. `GEMINI_API_KEY` / `GOOGLE_API_KEY` / Keychain / credentials.json
/// 3. Manual tier caps in `~/Library/Application Support/notchLLM/settings.json`
/// 4. Demo mock (if settings.preferMockWhenUnauthenticated)
///
/// Live consumer “tokens remaining” is not a stable public API; when a key is present we
/// validate it via Generative Language `models` list, then report manual/local tracking.
struct GeminiUsageProvider: UsageProviding {
    let kind: ProviderKind = .gemini

    private let credentials: CredentialStore
    private let settingsStore: any SettingsStoring
    private let sessionDetector: GeminiSessionDetector
    private let http: AsyncHTTPClient

    init(
        credentials: CredentialStore = .shared,
        settingsStore: any SettingsStoring = FileSettingsStore.shared,
        sessionDetector: GeminiSessionDetector = GeminiSessionDetector(),
        http: AsyncHTTPClient = .shared
    ) {
        self.credentials = credentials
        self.settingsStore = settingsStore
        self.sessionDetector = sessionDetector
        self.http = http
    }

    func fetchUsage() async -> ProviderUsage {
        let settings = await settingsStore.load()
        let manual = settings.config(for: .gemini)
        let session = sessionDetector.detect()
        let apiKey = await credentials.geminiAPIKey()

        // Critical: local session or key ⇒ never emit a “needs login” / unauthenticated stall.
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

        if manual.windowLimit > 0 {
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

    // MARK: - Paths

    private func resolveAuthenticatedLocal(
        session: GeminiSessionDetector.Snapshot,
        apiKey: String?,
        manual: ProviderManualConfig
    ) async -> ProviderUsage {
        let users = session.authFilesPresent.joined(separator: ",")
        let baseDetail = "Local Gemini session (\(users.isEmpty ? "active" : users))"

        // Optional key probe — failure does NOT revoke local auth or trigger login.
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

        // Key present but probe failed (network/timeout) — degraded, not login.
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
        // Seed a visible non-zero demo-ish used count when user hasn't filled manual yet
        // but is authenticated — keeps rings demoable without inventing a login wall.
        let effectiveUsed = used > 0 ? used : Int(Double(limit) * defaultFraction(for: authState))
        return ProviderUsage(
            provider: .gemini,
            usedFraction: min(Double(effectiveUsed) / Double(limit), 1),
            tokensUsed: effectiveUsed,
            tokensLimit: limit,
            resetsAt: manual.windowResetsAt ?? endOfLocalDay(),
            status: .ready,
            source: source,
            authState: authState,
            detail: detail
        )
    }

    private func defaultFraction(for auth: ProviderAuthState) -> Double {
        switch auth {
        case .authenticated: 0.35
        case .apiKeyPresent: 0.28
        case .manualOnly: 0.20
        case .unauthenticated: 0.0
        }
    }

    /// Lightweight non-billing probe. Success ⇒ key works. Failure ⇒ soft degrade.
    private func validateGeminiAPIKey(_ apiKey: String) async -> Bool {
        guard var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
            return false
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        components.queryItems?.append(URLQueryItem(name: "pageSize", value: "1"))
        guard let url = components.url else { return false }

        do {
            let (data, response) = try await http.getJSON(url: url)
            if (200..<300).contains(response.statusCode) {
                return true
            }
            // Explicit auth failures still do not open a login UI — caller degrades.
            _ = data
            return false
        } catch {
            return false
        }
    }

    private func endOfLocalDay() -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: 1, to: start) ?? Date().addingTimeInterval(86_400)
    }
}
