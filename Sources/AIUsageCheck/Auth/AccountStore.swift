import Foundation

/// Index of all configured accounts (display names + provider). Tokens live in `TokenStore`.
final class AccountStore {
    static let shared = AccountStore()

    private let url: URL
    private let queue = DispatchQueue(label: "AccountStore.fs")

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.url = fileURL
        } else {
            let support = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AIUsageCheck", isDirectory: true)
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            self.url = support.appendingPathComponent("accounts.json")
        }
    }

    func loadAll() -> [Account] {
        queue.sync {
            guard FileManager.default.fileExists(atPath: url.path) else { return [] }
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode([Account].self, from: data)
            } catch {
                Log.main.error("Failed to load accounts: \(error.localizedDescription)")
                return []
            }
        }
    }

    func saveAll(_ accounts: [Account]) {
        queue.sync {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(accounts)
                try data.write(to: url, options: .atomic)
            } catch {
                Log.main.error("Failed to save accounts: \(error.localizedDescription)")
            }
        }
    }
}
