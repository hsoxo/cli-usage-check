import Foundation

/// File-backed OAuth token storage. One JSON blob keyed by account UUID,
/// stored next to `accounts.json` in `~/Library/Application Support/AIUsageCheck/`.
/// Written with 0600 permissions so only the current user can read it.
struct TokenStore {
    private let url: URL
    private let queue = DispatchQueue(label: "TokenStore.fs")

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.url = fileURL
        } else {
            let support = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AIUsageCheck", isDirectory: true)
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            self.url = support.appendingPathComponent("tokens.json")
        }
    }

    func save(_ tokens: OAuthTokens, for accountID: UUID) throws {
        try queue.sync {
            var dict = readDict()
            dict[accountID.uuidString] = tokens
            try writeDict(dict)
        }
    }

    func load(for accountID: UUID) throws -> OAuthTokens? {
        queue.sync {
            readDict()[accountID.uuidString]
        }
    }

    func delete(for accountID: UUID) throws {
        try queue.sync {
            var dict = readDict()
            guard dict.removeValue(forKey: accountID.uuidString) != nil else { return }
            try writeDict(dict)
        }
    }

    // MARK: -

    private func readDict() -> [String: OAuthTokens] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([String: OAuthTokens].self, from: data)
        } catch {
            Log.auth.error("TokenStore read failed: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private func writeDict(_ dict: [String: OAuthTokens]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(dict)
        try data.write(to: url, options: .atomic)
        // Restrict to user-only after write.
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
