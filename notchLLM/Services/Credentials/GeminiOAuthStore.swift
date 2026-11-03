import Foundation

/// Reads / refreshes local Gemini / Antigravity OAuth without opening a browser.
///
/// Sources (first usable wins):
/// 1. `~/.gemini/jetski-standalone-oauth-token` (Antigravity / CodeNotch bridge)
/// 2. `~/.gemini/oauth_creds.json` (Gemini CLI)
///
/// Access tokens that are still valid are used as-is (no refresh, no login).
/// Refresh requires OAuth client material from the environment:
/// - `NOTCHLLM_ANTIGRAVITY_CLIENT_ID` / `NOTCHLLM_ANTIGRAVITY_CLIENT_SECRET`
/// - `NOTCHLLM_GEMINI_CLI_CLIENT_ID` / `NOTCHLLM_GEMINI_CLI_CLIENT_SECRET`
///
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
        if let jetski = loadJetski(), let refreshed = await ensureFresh(jetski) {
            return refreshed
        }
        if let cli = loadGeminiCLICreds(), let refreshed = await ensureFresh(cli) {
            return refreshed
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

    // MARK: - Refresh

    private func ensureFresh(_ bundle: TokenBundle) async -> TokenBundle? {
        if await probeToken(bundle.accessToken) {
            return bundle
        }
        guard let refresh = bundle.refreshToken, !refresh.isEmpty else {
            return nil
        }

        var clients: [(String, String, String)] = []
        if let id = env("NOTCHLLM_ANTIGRAVITY_CLIENT_ID"),
           let secret = env("NOTCHLLM_ANTIGRAVITY_CLIENT_SECRET") {
            clients.append(("antigravity", id, secret))
        }
        if let id = env("NOTCHLLM_GEMINI_CLI_CLIENT_ID"),
           let secret = env("NOTCHLLM_GEMINI_CLI_CLIENT_SECRET") {
            clients.append(("gemini-cli", id, secret))
        }
        // Soft discovery from local Antigravity install metadata (never baked into the binary).
        clients.append(contentsOf: discoverLocalOAuthClients())

        for (name, clientID, secret) in clients {
            if let access = await refreshAccessToken(refreshToken: refresh, clientID: clientID, clientSecret: secret) {
                return TokenBundle(accessToken: access, refreshToken: refresh, source: "\(bundle.source)+\(name)-refresh")
            }
        }
        return nil
    }

    private func probeToken(_ accessToken: String) async -> Bool {
        guard let encoded = accessToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=\(encoded)")
        else { return false }
        do {
            let (_, response) = try await http.getJSON(url: url)
            return (200..<300).contains(response.statusCode)
        } catch {
            return false
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
