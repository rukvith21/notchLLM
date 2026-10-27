import Foundation
import Observation

/// Editable settings surface. Saves JSON caps + Keychain secrets, then notifies the pill to refresh.
@MainActor
@Observable
final class SettingsViewModel {
    var preferMockWhenUnauthenticated = true
    var manualFallbackEnabled = true

    var geminiTier = "pro"
    var geminiLimit = 1_000_000
    var geminiUsed = 0
    var geminiAPIKeyInput = ""
    var geminiKeyPresent = false

    var chatGPTTier = "plus"
    var chatGPTLimit = 100_000
    var chatGPTUsed = 0
    var chatGPTAPIKeyInput = ""
    var chatGPTKeyPresent = false

    var cursorTier = "pro"
    var cursorLimit = 500
    var cursorUsed = 0
    var cursorAPIKeyInput = ""
    var cursorKeyPresent = false

    var statusMessage: String?
    var isSaving = false
    var isLoading = false

    private let settingsStore: any SettingsStoring
    private let credentials: CredentialStore

    init(
        settingsStore: any SettingsStoring = FileSettingsStore.shared,
        credentials: CredentialStore = .shared
    ) {
        self.settingsStore = settingsStore
        self.credentials = credentials
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let settings = await settingsStore.load()
        preferMockWhenUnauthenticated = settings.preferMockWhenUnauthenticated
        manualFallbackEnabled = settings.manualFallbackEnabled

        let gemini = settings.config(for: .gemini)
        geminiTier = gemini.tier
        geminiLimit = gemini.windowLimit
        geminiUsed = gemini.windowUsed

        let chat = settings.config(for: .chatGPT)
        chatGPTTier = chat.tier
        chatGPTLimit = chat.windowLimit
        chatGPTUsed = chat.windowUsed

        let cursor = settings.config(for: .cursor)
        cursorTier = cursor.tier
        cursorLimit = cursor.windowLimit
        cursorUsed = cursor.windowUsed

        geminiKeyPresent = await credentials.hasKeychainValue(account: .gemini)
        chatGPTKeyPresent = await credentials.hasKeychainValue(account: .openai)
        cursorKeyPresent = await credentials.hasKeychainValue(account: .cursor)

        geminiAPIKeyInput = ""
        chatGPTAPIKeyInput = ""
        cursorAPIKeyInput = ""
        statusMessage = nil
    }

    func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        var settings = await settingsStore.load()
        settings.preferMockWhenUnauthenticated = preferMockWhenUnauthenticated
        settings.manualFallbackEnabled = manualFallbackEnabled

        var gemini = settings.config(for: .gemini)
        gemini.tier = geminiTier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "pro" : geminiTier
        gemini.windowLimit = max(geminiLimit, 1)
        gemini.windowUsed = max(geminiUsed, 0)

        var chat = settings.config(for: .chatGPT)
        chat.tier = chatGPTTier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "plus" : chatGPTTier
        chat.windowLimit = max(chatGPTLimit, 1)
        chat.windowUsed = max(chatGPTUsed, 0)

        var cursor = settings.config(for: .cursor)
        cursor.tier = cursorTier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "pro" : cursorTier
        cursor.windowLimit = max(cursorLimit, 1)
        cursor.windowUsed = max(cursorUsed, 0)

        // Persist secrets to Keychain when the user typed a new value.
        if !geminiAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = await credentials.setAPIKey(geminiAPIKeyInput, account: .gemini)
        }
        if !chatGPTAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = await credentials.setAPIKey(chatGPTAPIKeyInput, account: .openai)
        }
        if !cursorAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = await credentials.setAPIKey(cursorAPIKeyInput, account: .cursor)
        }

        gemini.apiKeyHintPresent = await credentials.hasKeychainValue(account: .gemini)
        chat.apiKeyHintPresent = await credentials.hasKeychainValue(account: .openai)
        cursor.apiKeyHintPresent = await credentials.hasKeychainValue(account: .cursor)

        settings.setConfig(gemini, for: .gemini)
        settings.setConfig(chat, for: .chatGPT)
        settings.setConfig(cursor, for: .cursor)

        do {
            try await settingsStore.save(settings)
            geminiKeyPresent = gemini.apiKeyHintPresent
            chatGPTKeyPresent = chat.apiKeyHintPresent
            cursorKeyPresent = cursor.apiKeyHintPresent
            geminiAPIKeyInput = ""
            chatGPTAPIKeyInput = ""
            cursorAPIKeyInput = ""
            statusMessage = "Saved — rings refreshing…"
            NotificationCenter.default.post(name: .notchLLMSettingsDidChange, object: nil)
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func clearKey(for kind: ProviderKind) async {
        let account: CredentialStore.Account
        switch kind {
        case .gemini: account = .gemini
        case .chatGPT: account = .openai
        case .cursor: account = .cursor
        }
        _ = await credentials.setAPIKey(nil, account: account)

        var settings = await settingsStore.load()
        var config = settings.config(for: kind)
        config.apiKeyHintPresent = false
        settings.setConfig(config, for: kind)
        try? await settingsStore.save(settings)

        switch kind {
        case .gemini:
            geminiKeyPresent = false
            geminiAPIKeyInput = ""
        case .chatGPT:
            chatGPTKeyPresent = false
            chatGPTAPIKeyInput = ""
        case .cursor:
            cursorKeyPresent = false
            cursorAPIKeyInput = ""
        }
        statusMessage = "\(kind.displayName) key cleared"
        NotificationCenter.default.post(name: .notchLLMSettingsDidChange, object: nil)
    }
}
