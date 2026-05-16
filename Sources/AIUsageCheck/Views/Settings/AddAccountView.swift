import SwiftUI

struct AddAccountView: View {
    @ObservedObject var state: AppState
    let poller: UsagePoller
    @Environment(\.dismiss) private var dismiss

    @State private var provider: Provider = .claude
    @State private var displayName: String = ""

    // Manual paste fields
    @State private var accessToken: String = ""
    @State private var refreshToken: String = ""

    // Errors / progress
    @State private var importError: String?
    @State private var saveError: String?
    @State private var oauthError: String?
    @State private var isSaving = false

    // Browser-based OAuth state
    @State private var claudePending: ClaudeOAuth.PendingAuthorization?
    @State private var claudeCode: String = ""
    @State private var claudeExchanging = false
    @State private var codexInFlight: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add account").font(.title3.bold())

            Picker("Provider", selection: $provider) {
                ForEach(Provider.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: provider) { _, _ in resetFlowState() }

            section("Sign in with browser (recommended)") {
                browserLoginBlock
            }

            section("…or import the OAuth token from the CLI") {
                Button {
                    importFromCLI()
                } label: {
                    Label(importButtonTitle, systemImage: "square.and.arrow.down")
                }
                if let importError {
                    errorText(importError)
                }
            }

            section("…or paste tokens manually") {
                LabeledField(label: "Display name", placeholder: "e.g. Personal", text: $displayName)
                LabeledField(label: "Access token", placeholder: tokenPlaceholder, text: $accessToken, isSecure: true)
                LabeledField(label: "Refresh token (optional)", placeholder: "for auto-refresh", text: $refreshToken, isSecure: true)
                if let saveError { errorText(saveError) }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { cleanupAndClose() }
                Button {
                    saveManual()
                } label: {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Save manual token")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSaveManual || isSaving)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onDisappear { cleanup() }
    }

    // MARK: Browser login block

    @ViewBuilder
    private var browserLoginBlock: some View {
        switch provider {
        case .claude: claudeBlock
        case .codex:  codexBlock
        }
    }

    @ViewBuilder
    private var claudeBlock: some View {
        if let pending = claudePending {
            VStack(alignment: .leading, spacing: 6) {
                Text("Browser opened to claude.ai. After you authorize, the page shows a code — paste it below.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                LabeledField(label: "Authorization code", placeholder: "paste from browser",
                             text: $claudeCode, isSecure: false, isMonospaced: true)
                LabeledField(label: "Display name (optional)", placeholder: "e.g. Personal", text: $displayName)
                if let oauthError { errorText(oauthError) }
                HStack {
                    Button {
                        completeClaudeExchange(pending: pending)
                    } label: {
                        if claudeExchanging {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Complete sign-in")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(claudeCode.trimmingCharacters(in: .whitespaces).isEmpty || claudeExchanging)

                    Button("Cancel") {
                        claudePending = nil
                        claudeCode = ""
                        oauthError = nil
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Opens claude.ai in your browser. After approving, copy the code shown and paste it back here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button {
                    startClaude()
                } label: {
                    Label("Sign in with Claude", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                if let oauthError { errorText(oauthError) }
            }
        }
    }

    @ViewBuilder
    private var codexBlock: some View {
        if codexInFlight != nil {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for callback from chat.openai.com…")
                        .font(.system(size: 12))
                }
                Text("Complete the flow in your browser. The window closes automatically once tokens are saved.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let oauthError { errorText(oauthError) }
                Button("Cancel sign-in") {
                    codexInFlight?.cancel()
                    codexInFlight = nil
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Opens auth.openai.com in your browser. A local helper on port 1455 captures the callback automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                LabeledField(label: "Display name (optional)", placeholder: "e.g. Personal", text: $displayName)
                Button {
                    startCodex()
                } label: {
                    Label("Sign in with ChatGPT", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                if let oauthError { errorText(oauthError) }
            }
        }
    }

    // MARK: Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func errorText(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11))
            .foregroundStyle(.red)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var importButtonTitle: String {
        switch provider {
        case .claude: return "Import from ~/.claude/.credentials.json"
        case .codex:  return "Import from ~/.codex/auth.json"
        }
    }

    private var tokenPlaceholder: String {
        switch provider {
        case .claude: return "sk-ant-oat01-…"
        case .codex:  return "OpenAI access token"
        }
    }

    private var canSaveManual: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !accessToken.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: Actions

    private func resetFlowState() {
        claudePending = nil
        claudeCode = ""
        codexInFlight?.cancel()
        codexInFlight = nil
        oauthError = nil
        importError = nil
        saveError = nil
    }

    private func cleanup() {
        codexInFlight?.cancel()
        codexInFlight = nil
    }

    private func cleanupAndClose() {
        cleanup()
        dismiss()
    }

    private func startClaude() {
        oauthError = nil
        claudePending = ClaudeOAuth.beginInBrowser()
    }

    private func completeClaudeExchange(pending: ClaudeOAuth.PendingAuthorization) {
        oauthError = nil
        claudeExchanging = true
        let code = claudeCode
        let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Claude"
            : displayName
        Task { @MainActor in
            do {
                let tokens = try await ClaudeOAuth.completeExchange(pastedCode: code, pending: pending)
                let acc = try state.addAccount(provider: .claude, displayName: name, tokens: tokens)
                claudeExchanging = false
                cleanupAndClose()
                Task { await state.refresh(accountID: acc.id) }
            } catch {
                claudeExchanging = false
                oauthError = error.localizedDescription
            }
        }
    }

    private func startCodex() {
        oauthError = nil
        let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Codex"
            : displayName
        codexInFlight = Task { @MainActor in
            do {
                let tokens = try await CodexOAuth.runFlow()
                let acc = try state.addAccount(provider: .codex, displayName: name, tokens: tokens)
                codexInFlight = nil
                cleanupAndClose()
                Task { await state.refresh(accountID: acc.id) }
            } catch is CancellationError {
                codexInFlight = nil
            } catch {
                codexInFlight = nil
                oauthError = error.localizedDescription
            }
        }
    }

    private func importFromCLI() {
        importError = nil
        do {
            let tokens = try (provider == .claude
                ? CLIImporter.importClaude()
                : CLIImporter.importCodex())
            accessToken = tokens.accessToken
            refreshToken = tokens.refreshToken ?? ""
            if displayName.isEmpty {
                displayName = provider == .claude ? "Claude (imported)" : "Codex (imported)"
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    private func saveManual() {
        saveError = nil
        isSaving = true
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let access = accessToken.trimmingCharacters(in: .whitespaces)
        let refresh = refreshToken.trimmingCharacters(in: .whitespaces)
        let tokens = OAuthTokens(
            accessToken: access,
            refreshToken: refresh.isEmpty ? nil : refresh,
            expiresAt: nil
        )
        do {
            let acc = try state.addAccount(provider: provider, displayName: trimmedName, tokens: tokens)
            isSaving = false
            cleanupAndClose()
            Task { await state.refresh(accountID: acc.id) }
        } catch {
            isSaving = false
            saveError = error.localizedDescription
        }
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var isMonospaced: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12, design: (isSecure || isMonospaced) ? .monospaced : .default))
        }
    }
}
