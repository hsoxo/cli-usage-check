import Foundation

enum CodexClient {
    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    /// Mimics the official Codex CLI so the request looks like it came from there.
    static let userAgent = "codex_cli_rs/0.3.0 (macOS; arm64)"

    struct WhamResponse: Decodable {
        let plan_type: String?
        let rate_limit: RateLimit?

        struct RateLimit: Decodable {
            let primary_window: Window?
            let secondary_window: Window?
        }

        struct Window: Decodable {
            let used_percent: Double?
            let limit_window_seconds: Int?
            let reset_at: Double?
        }
    }

    static func fetchUsage(accessToken: String, accountID: String? = nil) async throws -> UsageSnapshot {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent,                forHTTPHeaderField: "User-Agent")
        request.setValue("codex_cli_rs",           forHTTPHeaderField: "originator")
        request.setValue("application/json",       forHTTPHeaderField: "Accept")
        if let accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "CodexClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CodexClient", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body.prefix(200))"])
        }

        let payload = try JSONDecoder().decode(WhamResponse.self, from: data)
        return UsageSnapshot(
            fiveHour: window(from: payload.rate_limit?.primary_window),
            sevenDay: window(from: payload.rate_limit?.secondary_window),
            planType: payload.plan_type,
            fetchedAt: Date()
        )
    }

    private static func window(from raw: WhamResponse.Window?) -> UsageWindow? {
        guard let raw, let pct = raw.used_percent else { return nil }
        let reset = raw.reset_at.map { Date(timeIntervalSince1970: $0) }
        return UsageWindow(utilization: pct / 100.0, resetAt: reset)
    }
}
