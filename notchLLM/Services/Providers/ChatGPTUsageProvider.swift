import Foundation

/// ChatGPT / Codex adapter — prefers live `wham/usage` over manual stubs.
///
/// Auth resolution:
/// 1. Codex `~/.codex/auth.json` → live `GET chatgpt.com/backend-api/wham/usage`
/// 2. `OPENAI_API_KEY` / Keychain probe + manual window
/// 3. Manual caps / demo mock
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

        if session.isAuthenticated, let token = session.accessToken {
            if let live = await fetchWhamUsage(token: token, accountID: session.accountID, manual: manual) {
                return live
            }
            // Session present but live call failed — still authenticated, no login loop.
            return compose(
                manual: manual,
                source: .localSession,
                authState: .authenticated,
                detail: "Codex session (\(session.accountID ?? session.authMode ?? "active")) · live usage unavailable · manual window"
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

        if settings.manualFallbackEnabled, manual.windowLimit > 0 {
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

    // MARK: - Live wham/usage

    private func fetchWhamUsage(
        token: String,
        accountID: String?,
        manual: ProviderManualConfig
    ) async -> ProviderUsage? {
        let candidates = [
            "https://chatgpt.com/backend-api/wham/usage",
            "https://chatgpt.com/backend-api/wham/usage?cedar_ember=1",
            "https://chatgpt.com/backend-api/wham/usage?include_extra_usage=true"
        ]
        var headerVariants: [[String: String]] = []
        var base = [
            "Authorization": "Bearer \(token)",
            "Accept": "application/json",
            "User-Agent": "codex-cli",
            "Origin": "https://chatgpt.com",
            "Referer": "https://chatgpt.com/"
        ]
        if let accountID, !accountID.isEmpty {
            base["ChatGPT-Account-ID"] = accountID
            headerVariants.append(base)
            var alt = base
            alt["chatgpt-account-id"] = accountID
            headerVariants.append(alt)
        } else {
            headerVariants.append(base)
        }

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            for headers in headerVariants {
                do {
                    let (data, response) = try await http.getJSON(url: url, headers: headers)
                    guard (200..<300).contains(response.statusCode),
                          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let parsed = parseWhamJSON(json, manual: manual)
                    else { continue }
                    return parsed
                } catch {
                    continue
                }
            }
        }
        return nil
    }

    private func parseWhamJSON(_ json: [String: Any], manual: ProviderManualConfig) -> ProviderUsage? {
        let plan = (json["plan_type"] as? String)
            ?? (json["planType"] as? String)
            ?? manual.tier
        let rate = (json["rate_limit"] as? [String: Any])
            ?? (json["rateLimit"] as? [String: Any])
            ?? (json["usage"] as? [String: Any])
        let windows = [
            rate?["primary_window"], rate?["secondary_window"],
            rate?["primaryWindow"], rate?["secondaryWindow"],
            json["primary_window"], json["secondary_window"]
        ]
            .compactMap { $0 as? [String: Any] }

        // Prefer the most constrained window (highest used_percent).
        var bestUsedPercent: Double?
        var bestReset: Date?
        var bestWindowSeconds: Int?
        for window in windows {
            let used = number(window["used_percent"])
                ?? number(window["usedPercent"])
                ?? number(window["percent_used"])
            guard let used else { continue }
            if bestUsedPercent == nil || used > (bestUsedPercent ?? -1) {
                bestUsedPercent = used
                bestWindowSeconds = (window["limit_window_seconds"] as? NSNumber)?.intValue
                    ?? (window["limitWindowSeconds"] as? NSNumber)?.intValue
                if let resetAt = window["reset_at"] as? NSNumber
                    ?? window["resetAt"] as? NSNumber {
                    bestReset = Date(timeIntervalSince1970: resetAt.doubleValue)
                } else if let after = window["reset_after_seconds"] as? NSNumber
                    ?? window["resetAfterSeconds"] as? NSNumber {
                    bestReset = Date().addingTimeInterval(after.doubleValue)
                }
            }
        }

        // Some payloads expose a single top-level used_percent.
        if bestUsedPercent == nil {
            bestUsedPercent = number(json["used_percent"]) ?? number(json["usedPercent"])
        }

        guard let usedPercent = bestUsedPercent else { return nil }
        let usedFraction = min(max(usedPercent / 100.0, 0), 1)
        let fallbackLimit = max(manual.windowLimit, 100)
        let derivedUsed = Int((usedFraction * Double(fallbackLimit)).rounded())
        let windowLabel: String = {
            switch bestWindowSeconds {
            case 18_000: return "5h"
            case 604_800: return "7d"
            case let seconds?: return "\(seconds)s"
            default: return "window"
            }
        }()

        return ProviderUsage(
            provider: .chatGPT,
            usedFraction: usedFraction,
            tokensUsed: derivedUsed,
            tokensLimit: fallbackLimit,
            resetsAt: bestReset ?? manual.windowResetsAt ?? endOfLocalDay(),
            status: .ready,
            source: .live,
            authState: .authenticated,
            detail: "ChatGPT \(plan) · live \(windowLabel) · \(Int((1 - usedFraction) * 100))% left"
        )
    }

    private func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
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
