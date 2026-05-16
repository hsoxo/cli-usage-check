import SwiftUI
import AppKit

@main
struct AIUsageCheckApp: App {
    @StateObject private var state = AppState.shared
    @StateObject private var prefs = Preferences.shared

    init() {
        Preferences.shared.load()
        // Kick the poller at launch so usage is fetched immediately and the
        // background timer keeps refreshing without waiting for the user to
        // open the popover.
        Task { @MainActor in
            UsagePoller.shared.start()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                state: state,
                prefs: prefs,
                poller: UsagePoller.shared,
                onQuit: quit
            )
        } label: {
            MenuBarLabel(state: state, prefs: prefs)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRoot(state: state, prefs: prefs, poller: UsagePoller.shared)
                .onDisappear {
                    // Re-hide the Dock icon once the settings window closes.
                    NSApp.setActivationPolicy(.accessory)
                }
        }
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
