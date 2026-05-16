import Foundation

struct UsageWindow: Codable, Hashable {
    /// 0.0 ... 1.0 (1.0 == fully consumed)
    var utilization: Double
    /// When this rolling window resets, or nil if unknown
    var resetAt: Date?

    var percentInt: Int { Int((utilization * 100).rounded()) }
}

struct UsageSnapshot: Codable, Hashable {
    var fiveHour: UsageWindow?
    var sevenDay: UsageWindow?
    var planType: String?
    var fetchedAt: Date
}

enum FetchStatus: Equatable {
    case idle
    case loading
    case ok(UsageSnapshot)
    case failed(String)

    var snapshot: UsageSnapshot? {
        if case .ok(let s) = self { return s }
        return nil
    }
}
