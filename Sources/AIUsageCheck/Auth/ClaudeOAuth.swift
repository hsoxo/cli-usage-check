import Foundation
import AppKit

/// Manual-paste OAuth flow for Claude (Pro/Max). The authorize page on
/// claude.ai displays the authorization code; the user copies it back into
/// the app, which then exchanges it for tokens.
enum ClaudeOAuth {
    static let authorizeURL  = URL(string: "https://claude.ai/oauth/authorize")!
    static let redirectURI   = "https://platform.claude.com/oauth/code/callback"
    static let scope         = "user:inference user:profile user:sessions:claude_code user:mcp_servers"

    /// State the caller must hold while the user is on claude.ai.
    struct PendingAuthorization {
        let pkce: PKCE.Pair
        let openedAt: Date
    }

    /// Opens the authorize URL in the user's default browser.
    @discardableResult
    static func beginInBrowser() -> PendingAuthorization {
        let pkce = PKCE.make(verifierByteLength: 32)
        var comps = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "code", value: "true"),                // shows the code on success
            URLQueryItem(name: "client_id", value: ClaudeAuth.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: pkce.state)
        ]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
        return PendingAuthorization(pkce: pkce, openedAt: Date())
    }

    /// Exchanges the authorization code shown on claude.ai for OAuth tokens.
    /// `pastedCode` is whatever the user pasted; it may include `#state` —
    /// we strip it.
    static func completeExchange(pastedCode: String,
                                 pending: PendingAuthorization) async throws -> OAuthTokens {
        let cleaned = pastedCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "#").first ?? ""
        guard !cleaned.isEmpty else {
            throw NSError(domain: "ClaudeOAuth", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Empty authorization code"])
        }

        var request = URLRequest(url: ClaudeAuth.refreshURL) // same /v1/oauth/token endpoint
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "grant_type":    "authorization_code",
            "code":          cleaned,
            "redirect_uri":  redirectURI,
            "client_id":     ClaudeAuth.clientID,
            "code_verifier": pending.pkce.verifier,
            "state":         pending.pkce.state
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ClaudeOAuth", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "Token exchange failed (\(code)): \(body.prefix(300))"])
        }
        let parsed = try JSONDecoder().decode(ClaudeAuth.RefreshResponse.self, from: data)
        let expiry = parsed.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) }
        return OAuthTokens(
            accessToken: parsed.access_token,
            refreshToken: parsed.refresh_token,
            expiresAt: expiry
        )
    }
}
