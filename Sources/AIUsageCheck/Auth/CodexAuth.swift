import Foundation

enum CodexAuth {
    /// OAuth client_id used by the Codex CLI. Reverse-engineered constant.
    static let clientID  = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let refreshURL = URL(string: "https://auth.openai.com/oauth/token")!

    struct RefreshResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let id_token: String?
        let expires_in: Int?
    }

    static func refresh(_ refreshToken: String) async throws -> OAuthTokens {
        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "client_id":     clientID,
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CodexAuth", code: code,
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
