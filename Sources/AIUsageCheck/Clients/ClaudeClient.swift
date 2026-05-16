import Foundation

enum ClaudeClient {
    static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    static let probeModel  = "claude-haiku-4-5-20251001"

    /// Probes /v1/messages with a 1-token haiku request and reads the unified rate-limit headers.
    static func fetchUsage(accessToken: String) async throws -> UsageSnapshot {
        var request = URLRequest(url: messagesURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01",            forHTTPHeaderField: "anthropic-version")
        request.setValue("oauth-2025-04-20",      forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json",      forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model":      probeModel,
            "max_tokens": 1,
            "messages":   [["role": "user", "content": "."]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ClaudeClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }

        // 401 / 403 are typically token issues; surface them clearly.
        if http.statusCode == 401 || http.statusCode == 403 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ClaudeClient", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Auth failed (\(http.statusCode)): \(body.prefix(200))"])
        }
        // 429 (rate limited) — still parse headers, that's actually useful info.
        if !(200..<300).contains(http.statusCode) && http.statusCode != 429 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ClaudeClient", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body.prefix(200))"])
        }

        let headers = http.allHeaderFields
        let fiveHour = parseWindow(headers: headers, prefix: "anthropic-ratelimit-unified-5h")
        let sevenDay = parseWindow(headers: headers, prefix: "anthropic-ratelimit-unified-7d")

        return UsageSnapshot(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            planType: nil,
            fetchedAt: Date()
        )
    }

    private static func parseWindow(headers: [AnyHashable: Any], prefix: String) -> UsageWindow? {
        let utilStr  = headerValue(headers, name: "\(prefix)-utilization")
        let resetStr = headerValue(headers, name: "\(prefix)-reset")
        guard let utilStr, let util = Double(utilStr) else { return nil }
        let reset = (resetStr.flatMap { TimeInterval($0) }).map(Date.init(timeIntervalSince1970:))
        return UsageWindow(utilization: util, resetAt: reset)
    }

    /// HTTP header lookup is case-insensitive in spec but not in `allHeaderFields`.
    private static func headerValue(_ headers: [AnyHashable: Any], name: String) -> String? {
        for (k, v) in headers {
            if let key = k as? String, key.caseInsensitiveCompare(name) == .orderedSame {
                return v as? String
            }
        }
        return nil
    }
}
