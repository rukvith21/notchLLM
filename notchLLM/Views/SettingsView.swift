import SwiftUI

/// Lightweight preferences window for API keys + manual fallback caps + auto-refresh.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            Form {
                Section("General") {
                    Toggle("Prefer demo mock when unsigned-in", isOn: $viewModel.preferMockWhenUnauthenticated)
                    Toggle("Enable manual fallback token caps", isOn: $viewModel.manualFallbackEnabled)

                    Picker("Auto-refresh", selection: $viewModel.autoRefreshSeconds) {
                        ForEach(SettingsViewModel.autoRefreshChoices, id: \.seconds) { choice in
                            Text(choice.label).tag(choice.seconds)
                        }
                    }
                    Text(autoRefreshHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Caps live in ~/Library/Application Support/notchLLM/settings.json. API keys go only to Keychain (service notchLLM) — never into the JSON file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                providerSection(
                    title: "ChatGPT / OpenAI",
                    hint: "Live Codex wham/usage when ~/.codex/auth.json is present; else OPENAI_API_KEY + manual window.",
                    tier: $viewModel.chatGPTTier,
                    limit: $viewModel.chatGPTLimit,
                    used: $viewModel.chatGPTUsed,
                    keyInput: $viewModel.chatGPTAPIKeyInput,
                    keyPresent: viewModel.chatGPTKeyPresent,
                    keyPreview: viewModel.chatGPTKeyPreview,
                    kind: .chatGPT
                )

                providerSection(
                    title: "Cursor",
                    hint: "Decrypts Cursor safe-storage token and reads dashboard get-current-period-usage.",
                    tier: $viewModel.cursorTier,
                    limit: $viewModel.cursorLimit,
                    used: $viewModel.cursorUsed,
                    keyInput: $viewModel.cursorAPIKeyInput,
                    keyPresent: viewModel.cursorKeyPresent,
                    keyPreview: viewModel.cursorKeyPreview,
                    kind: .cursor
                )

                providerSection(
                    title: "Gemini",
                    hint: "No login loop — jetski/Antigravity OAuth or local Gemini session; live Cloud Code quota when possible.",
                    tier: $viewModel.geminiTier,
                    limit: $viewModel.geminiLimit,
                    used: $viewModel.geminiUsed,
                    keyInput: $viewModel.geminiAPIKeyInput,
                    keyPresent: viewModel.geminiKeyPresent,
                    keyPreview: viewModel.geminiKeyPreview,
                    kind: .gemini
                )
            }
            .formStyle(.grouped)
            .disabled(viewModel.isLoading || viewModel.isSaving)

            footer
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 680)
        .task { await viewModel.load() }
    }

    private var autoRefreshHelp: String {
        if viewModel.autoRefreshSeconds == 0 {
            return "Rings refresh only when you click Refresh or save settings."
        }
        return "Rings poll live adapters every \(viewModel.autoRefreshSeconds)s while notchLLM is running."
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("notchLLM Settings")
                    .font(.title2.weight(.semibold))
                Text("Live usage, Keychain keys & manual caps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Reload") {
                Task { await viewModel.load() }
            }
            .disabled(viewModel.isSaving)
            Button("Save") {
                Task { await viewModel.save() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.isSaving || viewModel.isLoading)
        }
        .padding(16)
    }

    @ViewBuilder
    private func providerSection(
        title: String,
        hint: String,
        tier: Binding<String>,
        limit: Binding<Int>,
        used: Binding<Int>,
        keyInput: Binding<String>,
        keyPresent: Bool,
        keyPreview: String?,
        kind: ProviderKind
    ) -> some View {
        Section {
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Tier (free / pro / plus…)", text: tier)

            LabeledContent("Window limit") {
                TextField("Limit", value: limit, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            }
            LabeledContent("Window used") {
                TextField("Used", value: used, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            }

            let remaining = max(limit.wrappedValue - used.wrappedValue, 0)
            let pct: Int = {
                let safe = max(limit.wrappedValue, 1)
                return Int((Double(remaining) / Double(safe) * 100).rounded())
            }()
            Text("Manual fallback shows \(pct)% remaining (\(remaining) of \(max(limit.wrappedValue, 1)) left) when live data is missing.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            SecureField(
                keyPresent ? "Replace API key (Keychain)" : "API key (saved to Keychain)",
                text: keyInput
            )
            .textContentType(.password)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: keyPresent ? "checkmark.seal.fill" : "key.slash")
                    .foregroundStyle(keyPresent ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(keyPresent ? "Keychain key on file" : "No Keychain key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let keyPreview {
                        Text(keyPreview)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if keyPresent {
                    Button("Clear key", role: .destructive) {
                        Task { await viewModel.clearKey(for: kind) }
                    }
                    .controlSize(.small)
                }
            }
        } header: {
            Text(title)
        }
    }
}
