import Foundation

enum Formatting {
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.dateTimeStyle = .named
        return f
    }()

    /// "in 4h", "in 2d", "soon"
    static func relativeReset(_ date: Date?) -> String {
        guard let date else { return "—" }
        if date.timeIntervalSinceNow <= 0 { return "now" }
        return relative.localizedString(for: date, relativeTo: Date())
    }

    /// "14:23", "Mon 09:00"
    static func absoluteReset(_ date: Date?) -> String {
        guard let date else { return "—" }
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        if cal.isDateInToday(date) || cal.isDateInTomorrow(date) {
            f.dateFormat = "HH:mm"
        } else {
            f.dateFormat = "EEE HH:mm"
        }
        return f.string(from: date)
    }

    /// Compact remaining-time string until `date`: "2h50m", "2d3h", "5m", or "now".
    static func remainingTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        let secs = Int(date.timeIntervalSinceNow)
        if secs <= 0 { return "now" }
        let days = secs / 86_400
        let hours = (secs % 86_400) / 3600
        let minutes = (secs % 3600) / 60
        if days > 0 {
            return hours > 0 ? "\(days)d\(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h\(minutes)m" : "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }
}
