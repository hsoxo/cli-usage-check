import Foundation
import Security

/// Pulls OAuth tokens out of the locations the official CLIs write them to:
/// - Claude Code: `~/.claude/.credentials.json` (or macOS Keychain entry "Claude Code-credentials")
/// - Codex CLI:   `~/.codex/auth.json`
struct CLIImporter {
    enum ImportError: Error, LocalizedError {
        case notFound(String)
        case malformed(String)
        case apiKeyOnly(String)

        var errorDescription: String? {
            switch self {
            case .notFound(let path):     return "Not found: \(path) — run `claude` or `codex login` first."
            case .malformed(let detail):  return "Malformed credentials: \(detail)"
            case .apiKeyOnly(let detail): return "Only an API key is available, not an OAuth token. \(detail)"
            }
        }
    }

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    // MARK: Claude

    static func importClaude() throws -> OAuthTokens {
        // Prefer the file; fall back to Keychain.
        if let fromFile = try? readClaudeFile() { return fromFile }
        if let fromKC   = try? readClaudeKeychain() { return fromKC }
        throw ImportError.notFound("~/.claude/.credentials.json or Keychain entry 'Claude Code-credentials'")
    }

    private static func readClaudeFile() throws -> OAuthTokens {
        let url = home.appendingPathComponent(".claude/.credentials.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportError.notFound(url.path)
        }
        let data = try Data(contentsOf: url)
        return try parseClaudeCredentials(data)
    }

    private static func readClaudeKeychain() throws -> OAuthTokens {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw ImportError.notFound("Keychain 'Claude Code-credentials' (status \(status))")
        }
        return try parseClaudeCredentials(data)
    }

    private static func parseClaudeCredentials(_ data: Data) throws -> OAuthTokens {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let access = oauth["accessToken"] as? String else {
            throw ImportError.malformed("missing claudeAiOauth.accessToken")
        }
        let refresh = oauth["refreshToken"] as? String
        let expiresAt: Date? = (oauth["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000.0) }
        return OAuthTokens(accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
    }

    // MARK: Codex

    static func importCodex() throws -> OAuthTokens {
        let url = home.appendingPathComponent(".codex/auth.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportError.notFound(url.path)
        }
        let data = try Data(contentsOf: url)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.malformed("not a JSON object")
        }
        // OAuth (ChatGPT) flow keeps tokens under "tokens".
        if let tokens = obj["tokens"] as? [String: Any],
           let access = tokens["access_token"] as? String {
            let refresh = tokens["refresh_token"] as? String
            return OAuthTokens(accessToken: access, refreshToken: refresh, expiresAt: nil)
        }
        // API-key-only auth.json — usable for completions but not for /wham/usage.
        if obj["OPENAI_API_KEY"] is String {
            throw ImportError.apiKeyOnly("Run `codex logout && codex login` and choose ChatGPT to enable quota tracking.")
        }
        throw ImportError.malformed("unrecognized auth.json shape")
    }
}
