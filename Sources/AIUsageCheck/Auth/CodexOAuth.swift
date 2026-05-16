import Foundation
import AppKit

/// Browser-based OAuth login for Codex (ChatGPT Plus/Pro).
/// Uses a localhost HTTP server on port 1455 (or 1457 fallback) to capture
/// the redirect.
enum CodexOAuth {
    static let authorizeURL = URL(string: "https://auth.openai.com/oauth/authorize")!
    static let scope = "openid profile email offline_access api.connectors.read api.connectors.invoke"
    static let preferredPorts: [UInt16] = [1455, 1457]
    static let callbackPath = "/auth/callback"

    /// Runs the entire login flow: opens the browser, waits for the callback,
    /// exchanges the code for tokens.
    static func runFlow(timeout: TimeInterval = 300) async throws -> OAuthTokens {
        let server = try LoopbackOAuthServer(preferredPorts: preferredPorts, path: callbackPath)
        let pkce = PKCE.make(verifierByteLength: 64)
        let redirectURI = "http://localhost:\(server.port)\(callbackPath)"

        let authURL = buildAuthorizeURL(pkce: pkce, redirectURI: redirectURI)
        NSWorkspace.shared.open(authURL)

        let callback = try await server.waitForCallback(timeout: timeout)
        let (code, returnedState) = try parseCallback(callback)
        guard returnedState == pkce.state else {
            throw NSError(domain: "CodexOAuth", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "OAuth state mismatch"])
        }
        return try await exchangeCode(code: code, verifier: pkce.verifier, redirectURI: redirectURI)
    }

    // MARK: -

    private static func buildAuthorizeURL(pkce: PKCE.Pair, redirectURI: String) -> URL {
        var comps = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: CodexAuth.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: pkce.state),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "originator", value: "codex_cli_rs")
        ]
        return comps.url!
    }

    private static func parseCallback(_ url: URL) throws -> (code: String, state: String?) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "CodexOAuth", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad callback URL"])
        }
        let items = comps.queryItems ?? []
        if let err = items.first(where: { $0.name == "error" })?.value {
            let desc = items.first(where: { $0.name == "error_description" })?.value ?? ""
            throw NSError(domain: "CodexOAuth", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Authorization failed: \(err) \(desc)"])
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw NSError(domain: "CodexOAuth", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Callback missing code"])
        }
        let state = items.first(where: { $0.name == "state" })?.value
        return (code, state)
    }

    private static func exchangeCode(code: String,
                                     verifier: String,
                                     redirectURI: String) async throws -> OAuthTokens {
        var request = URLRequest(url: CodexAuth.refreshURL) // /oauth/token serves both grants
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = [
            "grant_type=authorization_code",
            "code=\(code.urlEncoded)",
            "redirect_uri=\(redirectURI.urlEncoded)",
            "client_id=\(CodexAuth.clientID)",
            "code_verifier=\(verifier.urlEncoded)"
        ].joined(separator: "&")
        request.httpBody = form.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CodexOAuth", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "Token exchange failed (\(code)): \(body.prefix(300))"])
        }
        let parsed = try JSONDecoder().decode(CodexAuth.RefreshResponse.self, from: data)
        let expiry = parsed.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) }
        return OAuthTokens(
            accessToken: parsed.access_token,
            refreshToken: parsed.refresh_token,
            expiresAt: expiry
        )
    }
}
