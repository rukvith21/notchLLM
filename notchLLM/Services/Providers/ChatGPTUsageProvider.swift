import Foundation

/// ChatGPT / Codex adapter (best-effort).
///
/// Assumptions:
/// - `~/.codex/auth.json` indicates an authenticated OpenAI/Codex account
/// - ChatGPT Atlas does not publish a stable local usage ledger we can read
/// - Live usage APIs vary by plan; we fall back to manual caps + mock
struct ChatGPTUsageProvider: UsageProviding {
    let kind: ProviderKind = .chatGPT

    private let credentials: CredentialStore
    private let settingsStore: any SettingsStoring
    private let sessionDetector: ChatGPTSessionDetector
    private let http: AsyncHTTPClient

    init(
        credentials: CredentialStore = .shared,
        settingsStore: any SettingsStoring = FileSettingsStore.shared,
        sessionDetector: ChatGPTSessionDetector = ChatGPTSessionDetector(),
        http: AsyncHTTPClient = .shared
    ) {
        self.credentials = credentials
        self.settingsStore = settingsStore
        self.sessionDetector = sessionDetector
        self.http = http
    }

    func fetchUsage() async -> ProviderUsage {
        let settings = await settingsStore.load()
        let manual = settings.config(for: .chatGPT)
        let session = sessionDetector.detect()
        let apiKey = await credentials.openAIAPIKey()

        if session.isAuthenticated {
            return compose(
                manual: manual,
                source: .localSession,
                authState: .authenticated,
                detail: "Codex session (\(session.accountID ?? session.authMode ?? "active")) · manual tracking"
            )
        }

        if let apiKey {
            let ok = await validateOpenAIKey(apiKey)
            return compose(
                manual: manual,
                source: ok ? .apiKeyValidated : .degraded,
                authState: .apiKeyPresent,
                detail: ok
                    ? "OpenAI API key valid · \(manual.tier) manual window"
                    : "OpenAI API key present · probe failed · manual cap"
            )
        }

        if manual.windowLimit > 0 {
            return .manual(
                for: .chatGPT,
                used: manual.windowUsed,
                limit: manual.windowLimit,
                resetsAt: manual.windowResetsAt ?? endOfLocalDay(),
                authState: .manualOnly,
                detail: "Manual \(manual.tier) cap · no Codex/OpenAI credentials"
            )
        }

        if settings.preferMockWhenUnauthenticated {
            return .mock(
                for: .chatGPT,
                usedFraction: 0.42,
                tokensUsed: 42_000,
                tokensLimit: 100_000,
                resetsIn: 2 * 86_400,
                detail: "Demo mock · sign in via Codex or set OPENAI_API_KEY",
                authState: .unauthenticated
            )
        }

        return ProviderUsage(
            provider: .chatGPT,
            usedFraction: nil,
            tokensUsed: nil,
            tokensLimit: nil,
            resetsAt: nil,
            status: .unavailable,
            source: .degraded,
            authState: .unauthenticated,
            detail: "No ChatGPT/Codex session or API key"
        )
    }

    private func compose(
        manual: ProviderManualConfig,
        source: UsageSource,
        authState: ProviderAuthState,
        detail: String
    ) -> ProviderUsage {
        let limit = max(manual.windowLimit, 1)
        let used = manual.windowUsed > 0 ? manual.windowUsed : Int(Double(limit) * 0.42)
        return ProviderUsage(
            provider: .chatGPT,
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

    private func validateOpenAIKey(_ apiKey: String) async -> Bool {
        guard let url = URL(string: "https://api.openai.com/v1/models") else { return false }
        do {
            let (_, response) = try await http.getJSON(
                url: url,
                headers: ["Authorization": "Bearer \(apiKey)"]
            )
            return (200..<300).contains(response.statusCode)
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
