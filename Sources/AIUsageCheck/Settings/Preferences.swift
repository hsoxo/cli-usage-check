import Foundation
import SwiftUI

/// Lightweight UserDefaults wrapper for persisted user settings.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Keys {
        static let pollIntervalSeconds = "pollIntervalSeconds"
        static let appearance = "appearance"
        static let lastError = "lastError"
    }

    /// 30..<3600 seconds. Default 120 (2 minutes).
    @Published var pollIntervalSeconds: Int = 0 {
        didSet { defaults.set(pollIntervalSeconds, forKey: Keys.pollIntervalSeconds) }
    }

    /// Appearance applied to the popover (Settings still follows the system).
    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .system: return "Follow system"
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    @Published var appearance: AppearanceMode = .system {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    func load() {
        let stored = defaults.integer(forKey: Keys.pollIntervalSeconds)
        pollIntervalSeconds = stored == 0 ? 120 : max(30, min(3600, stored))
        if let raw = defaults.string(forKey: Keys.appearance),
           let mode = AppearanceMode(rawValue: raw) {
            appearance = mode
        }
    }
}
