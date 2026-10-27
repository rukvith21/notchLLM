import Foundation

/// Phase-4-ready settings models. File-backed today; UI arrives in Phase 4.

struct NotchLLMSettings: Codable, Equatable, Sendable {
    var preferMockWhenUnauthenticated: Bool
    var providers: [String: ProviderManualConfig]

    static let `default` = NotchLLMSettings(
        preferMockWhenUnauthenticated: true,
        providers: [
            ProviderKind.gemini.rawValue: .geminiDefault,
            ProviderKind.chatGPT.rawValue: .chatGPTDefault,
            ProviderKind.cursor.rawValue: .cursorDefault
        ]
    )

    func config(for kind: ProviderKind) -> ProviderManualConfig {
        providers[kind.rawValue] ?? ProviderManualConfig.defaults(for: kind)
    }
}

struct ProviderManualConfig: Codable, Equatable, Sendable {
    /// Friendly tier label (free / pro / team / custom).
    var tier: String
    /// Manual window limit (tokens or request units).
    var windowLimit: Int
    /// Running used count inside the current window.
    var windowUsed: Int
    /// ISO8601 reset timestamp; nil → end of local day.
    var windowResetsAt: Date?
    /// Optional API key override (Phase 4 Settings UI writes here / Keychain).
    var apiKeyHintPresent: Bool

    static var geminiDefault: ProviderManualConfig {
        ProviderManualConfig(
            tier: "pro",
            windowLimit: 1_000_000,
            windowUsed: 0,
            windowResetsAt: nil,
            apiKeyHintPresent: false
        )
    }

    static var chatGPTDefault: ProviderManualConfig {
        ProviderManualConfig(
            tier: "plus",
            windowLimit: 100_000,
            windowUsed: 0,
            windowResetsAt: nil,
            apiKeyHintPresent: false
        )
    }

    static var cursorDefault: ProviderManualConfig {
        ProviderManualConfig(
            tier: "pro",
            windowLimit: 500,
            windowUsed: 0,
            windowResetsAt: nil,
            apiKeyHintPresent: false
        )
    }

    static func defaults(for kind: ProviderKind) -> ProviderManualConfig {
        switch kind {
        case .gemini: .geminiDefault
        case .chatGPT: .chatGPTDefault
        case .cursor: .cursorDefault
        }
    }
}

/// Optional secrets file shape (never committed). Keys may also live in Keychain / env.
struct CredentialsFile: Codable, Equatable, Sendable {
    var geminiAPIKey: String?
    var openAIAPIKey: String?
    var cursorAPIKey: String?
}
