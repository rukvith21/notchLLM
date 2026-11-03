import Foundation

/// Best-effort ChatGPT / Codex session detection.
///
/// Assumptions:
/// - Codex CLI stores OAuth under `~/.codex/auth.json` with `tokens.access_token` / `account_id`
/// - Live usage: `GET https://chatgpt.com/backend-api/wham/usage` with those credentials
/// - We never open a browser login flow from this adapter
struct ChatGPTSessionDetector: Sendable {
    struct Snapshot: Sendable {
        let hasCodexAuth: Bool
        let accountID: String?
        let accessToken: String?
        let authMode: String?

        var hasAccessToken: Bool { !(accessToken ?? "").isEmpty }
        var isAuthenticated: Bool { hasCodexAuth && hasAccessToken }
    }

    private let authURL: URL

    init(
        authURL: URL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/auth.json")
    ) {
        self.authURL = authURL
    }

    func detect() -> Snapshot {
        guard let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return Snapshot(hasCodexAuth: false, accountID: nil, accessToken: nil, authMode: nil)
        }

        let mode = json["auth_mode"] as? String
        let tokens = json["tokens"] as? [String: Any]
        let access = tokens?["access_token"] as? String
        let accountID = tokens?["account_id"] as? String

        return Snapshot(
            hasCodexAuth: true,
            accountID: accountID,
            accessToken: (access?.isEmpty == false) ? access : nil,
            authMode: mode
        )
    }
}
