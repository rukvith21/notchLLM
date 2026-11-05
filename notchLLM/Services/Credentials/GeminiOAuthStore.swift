import Foundation

/// Reads / refreshes local Gemini / Antigravity OAuth without opening a browser.
///
/// Sources (first usable wins):
/// 1. `~/.gemini/jetski-standalone-oauth-token` (Antigravity / CodeNotch bridge)
/// 2. `~/.gemini/oauth_creds.json` (Gemini CLI)
///
/// Access tokens are tried against Cloud Code quota first (no login).
/// Refresh only runs when the quota call returns 401 and client material exists.
/// Failures degrade silently — adapters never enter a login loop.
struct GeminiOAuthStore: Sendable {
    struct TokenBundle: Sendable {
        let accessToken: String
        let refreshToken: String?
        let source: String
    }

    private let home: URL
    private let http: AsyncHTTPClient

    init(
        home: URL = URL(fileURLWithPath: NSHomeDirectory()),
        http: AsyncHTTPClient = .shared
    ) {
        self.home = home
        self.http = http
    }

    func resolveAccessToken() async -> TokenBundle? {
        if let jetski = loadJetski(), let usable = await ensureUsable(jetski) {
            return usable
        }
        if let cli = loadGeminiCLICreds(), let usable = await ensureUsable(cli) {
            return usable
        }
        return nil
    }

    // MARK: - Loaders

    private func loadJetski() -> TokenBundle? {
        let url = home.appendingPathComponent(".gemini/jetski-standalone-oauth-token")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let token = (json["token"] as? [String: Any]) ?? json
        guard let access = token["access_token"] as? String, !access.isEmpty else { return nil }
        return TokenBundle(
            accessToken: access,
            refreshToken: token["refresh_token"] as? String,
            source: "jetski"
        )
    }

    private func loadGeminiCLICreds() -> TokenBundle? {
        let url = home.appendingPathComponent(".gemini/oauth_creds.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        guard let access = json["access_token"] as? String, !access.isEmpty else { return nil }
        return TokenBundle(
            accessToken: access,
            refreshToken: json["refresh_token"] as? String,
            source: "gemini-cli"
        )
    }

    // MARK: - Freshness

    /// Prefer the existing access token. Only refresh after a 401 probe against Cloud Code.
    /// Never opens a browser / login UI.
    private func ensureUsable(_ bundle: TokenBundle) async -> TokenBundle? {
        switch await probeCloudCode(bundle.accessToken) {
        case .ok, .other:
            // Token accepted, or non-auth failure — caller still tries quota with it.
            return bundle
        case .unauthorized:
            break
        }

        guard let refresh = bundle.refreshToken, !refresh.isEmpty else {
            // Access token rejected and no refresh — don't return a known-dead token.
            return nil
        }

        for (name, clientID, secret) in oauthClients() {
            if let access = await refreshAccessToken(
                refreshToken: refresh,
                clientID: clientID,
                clientSecret: secret
            ) {
                return TokenBundle(
                    accessToken: access,
                    refreshToken: refresh,
                    source: "\(bundle.source)+\(name)-refresh"
                )
            }
        }
        return nil
    }

    private enum ProbeResult {
        case ok
        case unauthorized
        case other
    }

    /// Lightweight auth check against a Cloud Code endpoint (same family as quota).
    private func probeCloudCode(_ accessToken: String) async -> ProbeResult {
        guard let url = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary")
        else { return .other }
        let headers = [
            "Authorization": "Bearer \(accessToken)",
            "Content-Type": "application/json",
            "User-Agent": "antigravity/1.11.3 Darwin/arm64",
            "Accept": "application/json"
        ]
        do {
            let (_, response) = try await http.postJSON(url: url, headers: headers, body: Data("{}".utf8))
            if (200..<300).contains(response.statusCode) { return .ok }
            if response.statusCode == 401 || response.statusCode == 403 { return .unauthorized }
            return .other
        } catch {
            return .other
        }
    }

    private func refreshAccessToken(refreshToken: String, clientID: String, clientSecret: String) async -> String? {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return nil }
        let form = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        do {
            let (data, response) = try await http.postForm(url: url, form: form)
            guard (200..<300).contains(response.statusCode),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = json["access_token"] as? String,
                  !access.isEmpty
            else { return nil }
            return access
        } catch {
            return nil
        }
    }

    private func oauthClients() -> [(String, String, String)] {
        var clients: [(String, String, String)] = []
        if let id = env("NOTCHLLM_ANTIGRAVITY_CLIENT_ID"),
           let secret = env("NOTCHLLM_ANTIGRAVITY_CLIENT_SECRET") {
            clients.append(("antigravity", id, secret))
        }
        if let id = env("NOTCHLLM_GEMINI_CLI_CLIENT_ID"),
           let secret = env("NOTCHLLM_GEMINI_CLI_CLIENT_SECRET") {
            clients.append(("gemini-cli", id, secret))
        }
        clients.append(contentsOf: discoverLocalOAuthClients())
        return clients
    }

    /// Best-effort: pull client id/secret pairs from a local notchLLM oauth helpers file if present.
    /// Path: `~/Library/Application Support/notchLLM/oauth-clients.json`
    /// Shape: `{ "clients": [ { "name": "antigravity", "clientId": "...", "clientSecret": "..." } ] }`
    private func discoverLocalOAuthClients() -> [(String, String, String)] {
        let url = home
            .appendingPathComponent("Library/Application Support/notchLLM/oauth-clients.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clients = json["clients"] as? [[String: Any]]
        else { return [] }

        var result: [(String, String, String)] = []
        for client in clients {
            guard let id = client["clientId"] as? String, !id.isEmpty,
                  let secret = client["clientSecret"] as? String, !secret.isEmpty
            else { continue }
            let name = (client["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "local"
            result.append((name, id, secret))
        }
        return result
    }

    private func env(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }
}
