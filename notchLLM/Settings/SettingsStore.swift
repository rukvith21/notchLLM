import Foundation

/// Persistence for manual tiers / caps. Phase 4 adds a Settings window on top.
protocol SettingsStoring: Sendable {
    func load() async -> NotchLLMSettings
    func save(_ settings: NotchLLMSettings) async throws
}

actor FileSettingsStore: SettingsStoring {
    static let shared = FileSettingsStore()

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("notchLLM", isDirectory: true)
        self.fileURL = fileURL ?? dir.appendingPathComponent("settings.json")
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() async -> NotchLLMSettings {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        guard fm.fileExists(atPath: fileURL.path) else {
            let defaults = NotchLLMSettings.default
            try? persist(defaults)
            return defaults
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(NotchLLMSettings.self, from: data)
        } catch {
            return NotchLLMSettings.default
        }
    }

    func save(_ settings: NotchLLMSettings) async throws {
        try persist(settings)
    }

    private func persist(_ settings: NotchLLMSettings) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: [.atomic])
    }
}
