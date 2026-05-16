import Foundation

struct Account: Codable, Identifiable, Hashable {
    let id: UUID
    var provider: Provider
    var displayName: String
    var createdAt: Date
    /// Whether this account's worst-window stats contribute to the menubar tray.
    /// Defaults to true; older accounts.json files without this field decode as true.
    var showInMenuBar: Bool

    init(id: UUID = UUID(),
         provider: Provider,
         displayName: String,
         createdAt: Date = Date(),
         showInMenuBar: Bool = true) {
        self.id = id
        self.provider = provider
        self.displayName = displayName
        self.createdAt = createdAt
        self.showInMenuBar = showInMenuBar
    }

    private enum CodingKeys: String, CodingKey {
        case id, provider, displayName, createdAt, showInMenuBar
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.provider = try c.decode(Provider.self, forKey: .provider)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.showInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
    }
}

struct OAuthTokens: Codable, Hashable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt.addingTimeInterval(-60)
    }
}
