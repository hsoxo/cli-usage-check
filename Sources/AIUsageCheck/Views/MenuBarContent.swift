import SwiftUI
import AppKit

struct MenuBarContent: View {
    @ObservedObject var state: AppState
    @ObservedObject var prefs: Preferences
    let poller: UsagePoller
    var onQuit: () -> Void

    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if state.accounts.isEmpty {
                empty
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(grouped, id: \.0) { provider, accounts in
                            providerCard(provider: provider, accounts: accounts)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: 400)
            }

            Divider().opacity(0.6)
            footer
        }
        .frame(width: 360)
        .background(backdrop)
        .preferredColorScheme(prefs.appearance.colorScheme)
    }

    // MARK: - Background

    private var backdrop: some View {
        ZStack {
            // ultraThinMaterial lets the desktop / window beneath show through more
            // than a solid `.background`, giving the popover a translucent glass feel.
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color.claudeOrange.opacity(0.07),
                    .clear,
                    Color.openAIGreen.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
            .opacity(0.5)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: -4) {
                ClaudeLogo(size: 14)
                CodexLogo(size: 14)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("AI Usage")
                    .font(.system(size: 13, weight: .semibold))
                if let last = state.lastRefreshAt {
                    Text("Updated \(Formatting.relativeReset(last))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Provider card

    private func providerCard(provider: Provider, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                provider.logoView(size: 13)
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(provider.brandColor)
                Spacer()
                Text("\(accounts.count) acct\(accounts.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            VStack(spacing: 8) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    AccountRow(account: account,
                               status: state.statuses[account.id] ?? .idle)
                    if index < accounts.count - 1 {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(provider.brandColor.opacity(0.18), lineWidth: 0.6)
        }
    }

    private var grouped: [(Provider, [Account])] {
        Provider.allCases.compactMap { p in
            let group = state.accounts.filter { $0.provider == p }
            return group.isEmpty ? nil : (p, group)
        }
    }

    // MARK: - Empty state

    private var empty: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ClaudeLogo(size: 28)
                CodexLogo(size: 28)
            }
            .padding(.bottom, 4)
            Text("No accounts yet")
                .font(.system(size: 13, weight: .semibold))
            Text("Add a Claude or Codex account to track your 5h and 7d quotas.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Open Settings…") { showSettings() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 4) {
            footerButton("Refresh", systemImage: "arrow.clockwise") {
                poller.refreshNow()
            }
            footerButton("Settings", systemImage: "gearshape") {
                showSettings()
            }
            Spacer()
            footerButton("Quit", systemImage: "power", isDestructive: true) {
                onQuit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func footerButton(_ label: String,
                              systemImage: String,
                              isDestructive: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isDestructive ? Color.red.opacity(0.85) : Color.primary.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.001))
        }
        .onHover { hovering in
            // Hover effect handled by macOS button style — kept for future tweaks.
            _ = hovering
        }
    }

    /// Activates the app then opens the Settings scene. Both steps are needed for
    /// LSUIElement apps where the settings window otherwise opens behind everything.
    private func showSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}
