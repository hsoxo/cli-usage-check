import Foundation
import Combine

@MainActor
final class UsagePoller {
    /// Shared instance so the poller can be started at app launch and reused by all views.
    static let shared = UsagePoller()

    private let appState: AppState
    private let prefs: Preferences
    private var task: Task<Void, Never>?
    private var prefsCancellable: AnyCancellable?
    private var started = false

    init(appState: AppState? = nil, prefs: Preferences? = nil) {
        self.appState = appState ?? .shared
        self.prefs = prefs ?? .shared
    }

    func start() {
        guard !started else { return }
        started = true
        prefsCancellable = prefs.$pollIntervalSeconds
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.restart() }
        restart()
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func refreshNow() {
        Task { @MainActor in
            await appState.refreshAll()
        }
    }

    private func restart() {
        task?.cancel()
        let interval = max(30, prefs.pollIntervalSeconds)
        Log.polling.info("Poller (re)started, interval=\(interval)s")
        task = Task { @MainActor [appState] in
            await appState.refreshAll()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                } catch { return }
                await appState.refreshAll()
            }
        }
    }
}
