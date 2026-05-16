import SwiftUI
import AppKit

/// Compact label shown in the menu bar tray.
///
/// MenuBarExtra labels are hosted inside an NSStatusItem button that
/// collapses multi-line SwiftUI views, so the entire stacked layout is
/// rendered into an NSImage off-screen via `ImageRenderer` and handed to the
/// menubar as a single bitmap. The image is marked as a template so macOS
/// tints it with the menubar's foreground color (white on dark, black on
/// light), matching the user's "white text and white logo" request without
/// disappearing on light menubars.
struct MenuBarLabel: View {
    @ObservedObject var state: AppState
    @ObservedObject var prefs: Preferences

    private let menuBarHeight: CGFloat = 22
    /// Nominal logo size — equal across providers for visual harmony.
    /// `ClaudeLogo` internally applies a visual-balance scale to compensate
    /// for the sunburst's thin rays.
    private let logoSize: CGFloat = 18

    var body: some View {
        Image(nsImage: renderedImage())
    }

    @MainActor
    private func renderedImage() -> NSImage {
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let img = renderer.nsImage ?? NSImage(size: NSSize(width: 1, height: menuBarHeight))
        img.isTemplate = true
        return img
    }

    @ViewBuilder
    private var content: some View {
        if visibleAccounts.isEmpty {
            Text("—")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 2)
                .frame(height: menuBarHeight)
        } else {
            HStack(spacing: 10) {
                // One chip per visible account so multiple accounts of the same
                // provider (e.g. two Codex logins) each surface their own stats
                // instead of being collapsed into a single worst-of aggregate.
                ForEach(visibleAccounts) { account in
                    accountChip(account)
                }
            }
            .padding(.horizontal, 2)
            .frame(height: menuBarHeight)
            .fixedSize()
        }
    }

    private func accountChip(_ account: Account) -> some View {
        let snapshot = state.statuses[account.id]?.snapshot
        return HStack(spacing: 5) {
            logo(for: account.provider)
            // Top line = 5h window, bottom line = 7d window. Position + the brand
            // logo identify both axes, so we drop the explicit "5h:"/"wk:" labels
            // for a cleaner tray.
            VStack(alignment: .leading, spacing: 1) {
                Text(line(window: snapshot?.fiveHour))
                Text(line(window: snapshot?.sevenDay))
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func logo(for provider: Provider) -> some View {
        switch provider {
        case .claude: ClaudeLogo(size: logoSize, color: .white)
        case .codex:  CodexLogo(size: logoSize, color: .white)
        }
    }

    private func line(window: UsageWindow?) -> String {
        guard let window else { return "—" }
        let pct = "\(window.percentInt)%"
        if let r = Formatting.remainingTime(window.resetAt) {
            return "\(pct)(\(r))"
        }
        return pct
    }

    private var visibleAccounts: [Account] { state.menuBarAccounts }
}
