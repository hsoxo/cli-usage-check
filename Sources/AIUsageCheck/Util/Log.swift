import Foundation
import os

enum Log {
    static let main      = Logger(subsystem: "com.hhe.aiusagecheck", category: "main")
    static let auth      = Logger(subsystem: "com.hhe.aiusagecheck", category: "auth")
    static let net       = Logger(subsystem: "com.hhe.aiusagecheck", category: "net")
    static let tokens    = Logger(subsystem: "com.hhe.aiusagecheck", category: "tokens")
    static let polling   = Logger(subsystem: "com.hhe.aiusagecheck", category: "polling")
}
