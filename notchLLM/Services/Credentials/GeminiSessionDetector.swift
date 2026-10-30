import Foundation

/// Detects an already-authenticated Gemini desktop / Antigravity session on disk.
/// Presence of local auth material means we must NOT enter a login loop.
struct GeminiSessionDetector: Sendable {
    struct Snapshot: Sendable {
        let hasAccountConfig: Bool
        let activeUserIDs: [String]
        let authFilesPresent: [String]
        let antigravityPresent: Bool

        var isAuthenticated: Bool {
            !authFilesPresent.isEmpty || (hasAccountConfig && !activeUserIDs.isEmpty) || antigravityPresent
        }
    }

    private let home: URL

    init(home: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.home = home
    }

    func detect() -> Snapshot {
        let geminiAppSupport = home
            .appendingPathComponent("Library/Application Support/com.google.GeminiMacOS")
        let accountConfig = geminiAppSupport.appendingPathComponent("account_config")
        let dataRoot = geminiAppSupport.appendingPathComponent("Data")

        let hasAccountConfig = FileManager.default.fileExists(atPath: accountConfig.path)
        let userIDs = parseUserIDs(from: accountConfig)
        var authFiles: [String] = []

        let candidates = userIDs.isEmpty ? ["user1", "user2"] : userIDs
        for userID in candidates {
            let authURL = dataRoot.appendingPathComponent(userID).appendingPathComponent("auth")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: authURL.path),
               let size = attrs[.size] as? NSNumber,
               size.intValue > 0 {
                authFiles.append(userID)
            }
        }

        let antigravity = home.appendingPathComponent(".gemini/antigravity/antigravity_state.pbtxt")
        let antigravityPresent = FileManager.default.fileExists(atPath: antigravity.path)

        return Snapshot(
            hasAccountConfig: hasAccountConfig,
            activeUserIDs: userIDs,
            authFilesPresent: authFiles,
            antigravityPresent: antigravityPresent
        )
    }

    /// `account_config` is a tiny protobuf-ish blob containing `user1` / `user2` ASCII labels.
    private func parseUserIDs(from url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let ascii = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8)
        else { return [] }

        var found: [String] = []
        for match in ["user1", "user2", "user3", "user4"] where ascii.contains(match) {
            found.append(match)
        }
        return found
    }
}
