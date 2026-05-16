import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var accounts: [Account] = []
    @Published private(set) var statuses: [UUID: FetchStatus] = [:]
    @Published private(set) var lastRefreshAt: Date?

    private let store: AccountStore
    private let tokenStore: TokenStore

    init(store: AccountStore = .shared, tokenStore: TokenStore = TokenStore()) {
        self.store = store
        self.tokenStore = tokenStore
        self.accounts = store.loadAll()
        for a in accounts { statuses[a.id] = .idle }
    }

    // MARK: Account management

    func addAccount(provider: Provider, displayName: String, tokens: OAuthTokens) throws -> Account {
        let acc = Account(provider: provider, displayName: displayName)
        try tokenStore.save(tokens, for: acc.id)
        accounts.append(acc)
        statuses[acc.id] = .idle
        store.saveAll(accounts)
        return acc
    }

    func updateTokens(for accountID: UUID, tokens: OAuthTokens) throws {
        try tokenStore.save(tokens, for: accountID)
    }

    func rename(accountID: UUID, to newName: String) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        accounts[idx].displayName = newName
        store.saveAll(accounts)
    }

    func setMenuBarVisible(accountID: UUID, _ visible: Bool) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        accounts[idx].showInMenuBar = visible
        store.saveAll(accounts)
    }

    func remove(accountID: UUID) {
        accounts.removeAll { $0.id == accountID }
        statuses.removeValue(forKey: accountID)
        try? tokenStore.delete(for: accountID)
        store.saveAll(accounts)
    }

    func tokens(for accountID: UUID) throws -> OAuthTokens? {
        try tokenStore.load(for: accountID)
    }

    // MARK: Refresh

    func refreshAll() async {
        for account in accounts {
            await refresh(account: account)
        }
        lastRefreshAt = Date()
    }

    func refresh(accountID: UUID) async {
        guard let account = accounts.first(where: { $0.id == accountID }) else { return }
        await refresh(account: account)
    }

    private func refresh(account: Account) async {
        statuses[account.id] = .loading
        do {
            guard var tokens = try tokenStore.load(for: account.id) else {
                statuses[account.id] = .failed("No saved tokens for \(account.displayName)")
                return
            }
            // Refresh access token if expired and we have a refresh token.
            if tokens.isExpired, let rt = tokens.refreshToken {
                do {
                    tokens = try await Self.performRefresh(provider: account.provider, refreshToken: rt)
                    try tokenStore.save(tokens, for: account.id)
                } catch {
                    Log.auth.error("Refresh failed for \(account.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    statuses[account.id] = .failed("Refresh failed: \(error.localizedDescription)")
                    return
                }
            }

            let snapshot: UsageSnapshot
            switch account.provider {
            case .claude:
                snapshot = try await ClaudeClient.fetchUsage(accessToken: tokens.accessToken)
            case .codex:
                snapshot = try await CodexClient.fetchUsage(accessToken: tokens.accessToken)
            }
            statuses[account.id] = .ok(snapshot)
        } catch {
            Log.net.error("Fetch failed for \(account.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            statuses[account.id] = .failed(error.localizedDescription)
        }
    }

    private static func performRefresh(provider: Provider, refreshToken: String) async throws -> OAuthTokens {
        switch provider {
        case .claude: return try await ClaudeAuth.refresh(refreshToken)
        case .codex:  return try await CodexAuth.refresh(refreshToken)
        }
    }

    // MARK: Aggregates for UI

    /// Accounts the user has opted to surface in the menubar tray.
    var menuBarAccounts: [Account] { accounts.filter { $0.showInMenuBar } }
}
