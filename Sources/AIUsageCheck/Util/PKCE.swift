import Foundation
import CryptoKit

enum PKCE {
    struct Pair {
        let verifier: String
        let challenge: String
        let state: String
    }

    /// Builds a PKCE verifier/challenge pair plus a CSRF state token.
    /// `verifierByteLength` is 32 for the Claude flow, 64 for the Codex flow.
    static func make(verifierByteLength: Int = 32) -> Pair {
        let verifier  = randomBase64URL(byteLength: verifierByteLength)
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state     = randomBase64URL(byteLength: 32)
        return Pair(verifier: verifier, challenge: challenge, state: state)
    }

    private static func randomBase64URL(byteLength: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteLength, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        return base64URL(Data(bytes))
    }

    private static func base64URL<D: DataProtocol>(_ data: D) -> String {
        Data(data).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
