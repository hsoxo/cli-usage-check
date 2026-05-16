import Foundation

enum ClaudeAuth {
    /// OAuth client_id used by the Claude Code CLI. Reverse-engineered constant.
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let refreshURL = URL(string: "https://platform.claude.com/v1/oauth/token")!

    struct RefreshResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int?
    }

    /// Exchanges a refresh token for a new access token. Throws on HTTP/JSON errors.
    static func refresh(_ refreshToken: String) async throws -> OAuthTokens {
        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken.urlEncoded)",
            "client_id=\(clientID)"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ClaudeAuth", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "Refresh failed (\(code)): \(body)"])
        }
        let parsed = try JSONDecoder().decode(RefreshResponse.self, from: data)
        let expiry = parsed.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) }
        return OAuthTokens(
            accessToken: parsed.access_token,
            refreshToken: parsed.refresh_token ?? refreshToken,
            expiresAt: expiry
        )
    }
}

extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
