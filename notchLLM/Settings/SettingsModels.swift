import Foundation

struct NotchLLMSettings: Codable, Equatable, Sendable {
    var preferMockWhenUnauthenticated: Bool
    /// When true, adapters use per-provider windowLimit/windowUsed if live data is missing.
    var manualFallbackEnabled: Bool
    var providers: [String: ProviderManualConfig]

    static let `default` = NotchLLMSettings(
        preferMockWhenUnauthenticated: true,
        manualFallbackEnabled: true,
        providers: [
            ProviderKind.gemini.rawValue: .geminiDefault,
            ProviderKind.chatGPT.rawValue: .chatGPTDefault,
            ProviderKind.cursor.rawValue: .cursorDefault
        ]
    )

    func config(for kind: ProviderKind) -> ProviderManualConfig {
        providers[kind.rawValue] ?? ProviderManualConfig.defaults(for: kind)
    }

    mutating func setConfig(_ config: ProviderManualConfig, for kind: ProviderKind) {
        providers[kind.rawValue] = config
    }

    enum CodingKeys: String, CodingKey {
        case preferMockWhenUnauthenticated
        case manualFallbackEnabled
        case providers
    }

    init(
        preferMockWhenUnauthenticated: Bool,
        manualFallbackEnabled: Bool,
        providers: [String: ProviderManualConfig]
    ) {
        self.preferMockWhenUnauthenticated = preferMockWhenUnauthenticated
        self.manualFallbackEnabled = manualFallbackEnabled
        self.providers = providers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferMockWhenUnauthenticated = try container.decodeIfPresent(Bool.self, forKey: .preferMockWhenUnauthenticated) ?? true
        manualFallbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .manualFallbackEnabled) ?? true
        providers = try container.decodeIfPresent([String: ProviderManualConfig].self, forKey: .providers)
            ?? NotchLLMSettings.default.providers
    }
}

struct ProviderManualConfig: Codable, Equatable, Sendable {
    var tier: String
    var windowLimit: Int
    var windowUsed: Int
    var windowResetsAt: Date?
    /// True when a Keychain secret exists for this provider (never stores the secret itself).
    var apiKeyHintPresent: Bool

    static var geminiDefault: ProviderManualConfig {
        ProviderManualConfig(tier: "pro", windowLimit: 1_000_000, windowUsed: 0, windowResetsAt: nil, apiKeyHintPresent: false)
    }

    static var chatGPTDefault: ProviderManualConfig {
        ProviderManualConfig(tier: "plus", windowLimit: 100_000, windowUsed: 0, windowResetsAt: nil, apiKeyHintPresent: false)
    }

    static var cursorDefault: ProviderManualConfig {
        ProviderManualConfig(tier: "pro", windowLimit: 500, windowUsed: 0, windowResetsAt: nil, apiKeyHintPresent: false)
    }

    static func defaults(for kind: ProviderKind) -> ProviderManualConfig {
        switch kind {
        case .gemini: .geminiDefault
        case .chatGPT: .chatGPTDefault
        case .cursor: .cursorDefault
        }
    }
}

struct CredentialsFile: Codable, Equatable, Sendable {
    var geminiAPIKey: String?
    var openAIAPIKey: String?
    var cursorAPIKey: String?
}

extension Notification.Name {
    static let notchLLMSettingsDidChange = Notification.Name("notchLLM.settingsDidChange")
}
