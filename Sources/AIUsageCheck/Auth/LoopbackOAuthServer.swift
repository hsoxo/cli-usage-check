import Foundation
import Network

/// Tiny one-shot HTTP server for capturing the OAuth `?code=...&state=...`
/// callback that the browser redirects to after the user authorizes.
///
/// Lifecycle:
///     let server = try LoopbackOAuthServer(preferredPorts: [1455, 1457], path: "/auth/callback")
///     let url = try await server.waitForCallback(timeout: 300)
///
/// The first matching request is parsed and the listener is shut down. The
/// browser sees a friendly success/error HTML page.
final class LoopbackOAuthServer {
    enum ServerError: Error, LocalizedError {
        case bindFailed(String)
        case timedOut
        case cancelled
        case malformed(String)

        var errorDescription: String? {
            switch self {
            case .bindFailed(let s): return "Could not start callback server: \(s)"
            case .timedOut:          return "Authorization timed out."
            case .cancelled:         return "Authorization cancelled."
            case .malformed(let s):  return "Malformed callback: \(s)"
            }
        }
    }

    let port: UInt16
    let callbackPath: String
    private let listener: NWListener
    private let queue = DispatchQueue(label: "LoopbackOAuthServer")

    private var continuation: CheckedContinuation<URL, Error>?
    private var didFinish = false

    /// Tries each preferred port in turn; throws if all are taken.
    init(preferredPorts: [UInt16], path: String) throws {
        self.callbackPath = path
        var lastError: Error?
        for candidate in preferredPorts {
            do {
                let params = NWParameters.tcp
                params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback),
                                                        port: NWEndpoint.Port(rawValue: candidate)!)
                let l = try NWListener(using: params)
                self.listener = l
                self.port = candidate
                return
            } catch {
                lastError = error
            }
        }
        throw ServerError.bindFailed(lastError?.localizedDescription ?? "no free port")
    }

    /// Starts the server and resolves once the browser hits the callback.
    func waitForCallback(timeout: TimeInterval) async throws -> URL {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            queue.async {
                self.continuation = cont
                self.listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
                self.listener.start(queue: self.queue)
            }
            // Cancel on timeout
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.fail(.timedOut)
            }
        }
    }

    /// Aborts an in-flight wait (e.g. user clicked Cancel).
    func cancel() { fail(.cancelled) }

    // MARK: -

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(on: conn, accumulated: Data())
    }

    private func receive(on conn: NWConnection, accumulated: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                Log.auth.error("LoopbackOAuthServer recv error: \(error.localizedDescription, privacy: .public)")
                conn.cancel(); return
            }
            var buf = accumulated
            if let data { buf.append(data) }

            // Wait until headers terminator.
            guard let crlfRange = buf.range(of: Data("\r\n\r\n".utf8)) else {
                if !isComplete {
                    self.receive(on: conn, accumulated: buf)
                }
                return
            }

            let header = String(data: buf.subdata(in: 0..<crlfRange.lowerBound), encoding: .utf8) ?? ""
            self.respondAndFinish(conn: conn, requestHead: header)
        }
    }

    private func respondAndFinish(conn: NWConnection, requestHead: String) {
        // Parse: "GET /auth/callback?code=...&state=... HTTP/1.1"
        guard let firstLine = requestHead.split(separator: "\r\n").first else {
            sendResponse(conn, status: 400, body: "Bad request")
            return
        }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendResponse(conn, status: 400, body: "Bad request")
            return
        }
        let path = String(parts[1])
        guard path.hasPrefix(callbackPath),
              let url = URL(string: "http://127.0.0.1:\(port)\(path)") else {
            sendResponse(conn, status: 404, body: "Not found")
            return
        }
        // Reply with friendly HTML, then resolve the continuation.
        sendResponse(conn, status: 200, body: Self.successHTML, contentType: "text/html; charset=utf-8")
        finish(with: .success(url))
    }

    private func sendResponse(_ conn: NWConnection, status: Int, body: String, contentType: String = "text/plain; charset=utf-8") {
        let bodyData = Data(body.utf8)
        let head = """
        HTTP/1.1 \(status) \(httpReason(status))\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r

        """
        var resp = Data(head.utf8)
        resp.append(bodyData)
        conn.send(content: resp, completion: .contentProcessed { _ in conn.cancel() })
    }

    private func httpReason(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        default:  return "Status"
        }
    }

    private func fail(_ error: ServerError) { finish(with: .failure(error)) }

    private func finish(with result: Result<URL, Error>) {
        queue.async {
            guard !self.didFinish else { return }
            self.didFinish = true
            self.listener.cancel()
            switch result {
            case .success(let url): self.continuation?.resume(returning: url)
            case .failure(let e):   self.continuation?.resume(throwing: e)
            }
            self.continuation = nil
        }
    }

    static let successHTML = """
    <!doctype html><html><head><meta charset="utf-8"><title>Signed in</title>
    <style>
      body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#0d1117;color:#e6edf3;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}
      .card{background:#161b22;border:1px solid #30363d;border-radius:14px;padding:36px 40px;max-width:420px;text-align:center}
      h1{margin:0 0 8px;font-size:18px}
      p{margin:8px 0 0;color:#8b949e;font-size:13px}
    </style></head>
    <body><div class="card">
      <h1>✓ Signed in</h1>
      <p>You can close this tab and return to AI Usage Check.</p>
    </div></body></html>
    """
}
