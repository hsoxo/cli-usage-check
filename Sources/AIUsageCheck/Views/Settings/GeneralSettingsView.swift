import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @ObservedObject var prefs: Preferences

    @State private var launchAtLogin: Bool = false
    @State private var launchAtLoginAvailable: Bool = true
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Polling") {
                Stepper(value: $prefs.pollIntervalSeconds, in: 30...3600, step: 30) {
                    Text("Refresh every \(prefs.pollIntervalSeconds)s")
                        .font(.system(size: 12, design: .monospaced))
                }
                Text("Each poll sends ~1 token to Anthropic and 1 GET to OpenAI per account. 120s is the default.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Popover theme", selection: $prefs.appearance) {
                    ForEach(Preferences.AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text("Applied to the menu bar popover. The Settings window always follows the system.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in updateLoginItem(enabled: newValue) }
                    .disabled(!launchAtLoginAvailable)
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear { syncLoginItemStatus() }
    }

    private func syncLoginItemStatus() {
        let svc = SMAppService.mainApp
        switch svc.status {
        case .enabled:           launchAtLogin = true
        case .notRegistered, .notFound: launchAtLogin = false
        case .requiresApproval:  launchAtLogin = false; launchAtLoginError = "Approval required in System Settings."
        @unknown default:        launchAtLogin = false
        }
    }

    private func updateLoginItem(enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLogin = !enabled  // revert
        }
    }
}
