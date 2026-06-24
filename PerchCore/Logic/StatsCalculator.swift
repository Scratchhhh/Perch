import Foundation

public struct EventStat: Sendable, Equatable {
    public let timestamp: Date
    public let acknowledgedAt: Date?
    public let isNotable: Bool

    public init(timestamp: Date, acknowledgedAt: Date?, isNotable: Bool) {
        self.timestamp = timestamp
        self.acknowledgedAt = acknowledgedAt
        self.isNotable = isNotable
    }
}

public struct DayCount: Sendable, Equatable, Identifiable {
    public let day: Date
    public let count: Int
    public var id: Date { day }

    public init(day: Date, count: Int) {
        self.day = day
        self.count = count
    }
}

public struct StatsSummary: Sendable, Equatable {
    public let savedMinutes: Int
    public let streakDays: Int
    public let totalNotable: Int
    public let perDay: [DayCount]
}

/// Turns the stored event log into the dashboard numbers: minutes of waiting Perch saved (the gap
/// between an agent reporting done/waiting and the user actually coming back), a day streak, and a
/// per-day histogram.
public enum StatsCalculator {
    /// A single event can't have "saved" more than this — covers walking away for the weekend.
    public static let perEventCapSeconds: TimeInterval = 2 * 60 * 60

    public static func summarize(
        _ events: [EventStat],
        now: Date,
        calendar: Calendar = .current,
        days: Int = 14
    ) -> StatsSummary {
        let notable = events.filter(\.isNotable)

        var savedSeconds: TimeInterval = 0
        for event in notable {
            guard let acknowledged = event.acknowledgedAt, acknowledged > event.timestamp else { continue }
            savedSeconds += min(acknowledged.timeIntervalSince(event.timestamp), perEventCapSeconds)
        }

        let notableDays = Set(notable.map { calendar.startOfDay(for: $0.timestamp) })
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while notableDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        let today = calendar.startOfDay(for: now)
        var perDay: [DayCount] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let count = notable.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.count
            perDay.append(DayCount(day: day, count: count))
        }

        return StatsSummary(
            savedMinutes: Int(savedSeconds / 60),
            streakDays: streak,
            totalNotable: notable.count,
            perDay: perDay
        )
    }
}
