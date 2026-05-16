import SwiftUI

struct SettingsRoot: View {
    @ObservedObject var state: AppState
    @ObservedObject var prefs: Preferences
    let poller: UsagePoller

    var body: some View {
        TabView {
            AccountsListView(state: state, poller: poller)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem { Label("Accounts", systemImage: "person.2") }
            GeneralSettingsView(prefs: prefs)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            AboutView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        // Pin the whole settings window so all three tabs render at the same
        // width/height — without this, each child dictates its own size and
        // switching tabs causes the window to grow or shrink.
        .frame(width: 560, height: 420)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI Usage Check").font(.title3.bold())
            Text("Menubar app showing 5h and 7-day Claude / Codex subscription quota usage. Multi-account.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Divider()
            Group {
                Text("Tokens").font(.system(size: 12, weight: .semibold))
                Text("• Claude: probes /v1/messages with a 1-token haiku call and reads `anthropic-ratelimit-unified-*` response headers.")
                Text("• Codex: GET https://chatgpt.com/backend-api/wham/usage (reverse-engineered from the official Codex CLI).")
                Text("• Tokens and account index live in ~/Library/Application Support/AIUsageCheck/ (tokens.json + accounts.json, 0600 perms).")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            Divider()
            Text("Reverse-engineered endpoints may change without notice. If your account stops fetching, sign out / in to the official CLI and re-import.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
