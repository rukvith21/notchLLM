import SwiftUI

/// Lightweight preferences window for API keys + manual fallback caps.
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
                    Text("Caps are stored in ~/Library/Application Support/notchLLM/settings.json. API keys go to Keychain (service notchLLM).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                providerSection(
                    title: "Gemini",
                    tier: $viewModel.geminiTier,
                    limit: $viewModel.geminiLimit,
                    used: $viewModel.geminiUsed,
                    keyInput: $viewModel.geminiAPIKeyInput,
                    keyPresent: viewModel.geminiKeyPresent,
                    kind: .gemini
                )

                providerSection(
                    title: "ChatGPT / OpenAI",
                    tier: $viewModel.chatGPTTier,
                    limit: $viewModel.chatGPTLimit,
                    used: $viewModel.chatGPTUsed,
                    keyInput: $viewModel.chatGPTAPIKeyInput,
                    keyPresent: viewModel.chatGPTKeyPresent,
                    kind: .chatGPT
                )

                providerSection(
                    title: "Cursor",
                    tier: $viewModel.cursorTier,
                    limit: $viewModel.cursorLimit,
                    used: $viewModel.cursorUsed,
                    keyInput: $viewModel.cursorAPIKeyInput,
                    keyPresent: viewModel.cursorKeyPresent,
                    kind: .cursor
                )
            }
            .formStyle(.grouped)
            .disabled(viewModel.isLoading || viewModel.isSaving)

            footer
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 560)
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("notchLLM Settings")
                    .font(.title2.weight(.semibold))
                Text("Keys & fallback caps")
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
        tier: Binding<String>,
        limit: Binding<Int>,
        used: Binding<Int>,
        keyInput: Binding<String>,
        keyPresent: Bool,
        kind: ProviderKind
    ) -> some View {
        Section(title) {
            TextField("Tier (free / pro / plus…)", text: tier)
            TextField("Window limit", value: limit, format: .number)
            TextField("Window used", value: used, format: .number)

            SecureField(keyPresent ? "Replace API key (saved in Keychain)" : "API key (saved in Keychain)", text: keyInput)
                .textContentType(.password)

            HStack {
                Image(systemName: keyPresent ? "checkmark.seal.fill" : "key.slash")
                    .foregroundStyle(keyPresent ? Color.green : Color.secondary)
                Text(keyPresent ? "Keychain key on file" : "No Keychain key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if keyPresent {
                    Button("Clear key", role: .destructive) {
                        Task { await viewModel.clearKey(for: kind) }
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}
