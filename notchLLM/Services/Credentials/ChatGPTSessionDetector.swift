import Foundation

/// Best-effort ChatGPT / Codex session detection.
///
/// Assumptions:
/// - Codex CLI stores OAuth under `~/.codex/auth.json` with `tokens.access_token` / `account_id`
/// - ChatGPT desktop (Atlas) does not expose a stable public usage file; we treat Codex auth
///   and `OPENAI_API_KEY` as sufficient “already authenticated” signals
/// - We never open a browser login flow from this adapter
struct ChatGPTSessionDetector: Sendable {
    struct Snapshot: Sendable {
        let hasCodexAuth: Bool
        let accountID: String?
        let hasAccessToken: Bool
        let authMode: String?

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
            return Snapshot(hasCodexAuth: false, accountID: nil, hasAccessToken: false, authMode: nil)
        }

        let mode = json["auth_mode"] as? String
        let tokens = json["tokens"] as? [String: Any]
        let access = tokens?["access_token"] as? String
        let accountID = tokens?["account_id"] as? String

        return Snapshot(
            hasCodexAuth: true,
            accountID: accountID,
            hasAccessToken: !(access ?? "").isEmpty,
            authMode: mode
        )
    }
}
