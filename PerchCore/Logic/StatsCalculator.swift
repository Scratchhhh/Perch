import Foundation

public struct EventStat: Sendable, Equatable {
    public let timestamp: Date
    public let acknowledgedAt: Date?
    /// Worth showing in history/streak/histogram (a finish or an attention prompt).
    public let isNotable: Bool
    /// Actually demanded attention (needs-input / permission / blocked). Only these count toward
    /// focus saved; a finish never kept anyone waiting at the keyboard.
    public let demandsAttention: Bool

    public init(timestamp: Date, acknowledgedAt: Date?, isNotable: Bool, demandsAttention: Bool) {
        self.timestamp = timestamp
        self.acknowledgedAt = acknowledgedAt
        self.isNotable = isNotable
        self.demandsAttention = demandsAttention
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
    /// Minutes of focus protected, measured as the union of "waiting on you" intervals.
    public let focusSavedMinutes: Int
    /// Attention prompts the user closed through Perch (acknowledged).
    public let contextSwitchesAvoided: Int
    public let streakDays: Int
    public let totalNotable: Int
    public let perDay: [DayCount]

    public init(
        focusSavedMinutes: Int,
        contextSwitchesAvoided: Int,
        streakDays: Int,
        totalNotable: Int,
        perDay: [DayCount]
    ) {
        self.focusSavedMinutes = focusSavedMinutes
        self.contextSwitchesAvoided = contextSwitchesAvoided
        self.streakDays = streakDays
        self.totalNotable = totalNotable
        self.perDay = perDay
    }
}

/// Turns the stored event log into the dashboard numbers.
///
/// Focus saved is the union of the intervals during which an agent was actually waiting on you, so
/// two agents waiting through the same lunch break count that lunch once rather than twice.
public enum StatsCalculator {
    /// A single waiting interval can credit at most this. Past half an hour you've walked away on
    /// your own, so Perch isn't really saving you from staring at a prompt. The old 2h cap is what
    /// let a few overnight gaps balloon the headline number.
    public static let focusIntervalCapSeconds: TimeInterval = 30 * 60

    public static func summarize(
        _ events: [EventStat],
        now: Date,
        calendar: Calendar = .current,
        days: Int = 14
    ) -> StatsSummary {
        let notable = events.filter(\.isNotable)
        let attention = events.filter(\.demandsAttention)

        let focusSavedSeconds = unionDurationSeconds(of: attention, cap: focusIntervalCapSeconds)
        let contextSwitchesAvoided = attention.filter { $0.acknowledgedAt != nil }.count

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
            focusSavedMinutes: Int(focusSavedSeconds / 60),
            contextSwitchesAvoided: contextSwitchesAvoided,
            streakDays: streak,
            totalNotable: notable.count,
            perDay: perDay
        )
    }

    /// Caps each acknowledged waiting interval, merges any that overlap or touch, and returns the
    /// total length. Merging is what stops parallel agents from counting the same minutes twice.
    static func unionDurationSeconds(of events: [EventStat], cap: TimeInterval) -> TimeInterval {
        var intervals: [(start: Date, end: Date)] = []
        for event in events {
            guard let acknowledged = event.acknowledgedAt, acknowledged > event.timestamp else { continue }
            let cappedEnd = min(acknowledged, event.timestamp.addingTimeInterval(cap))
            intervals.append((event.timestamp, cappedEnd))
        }
        guard !intervals.isEmpty else { return 0 }

        intervals.sort { $0.start < $1.start }

        var total: TimeInterval = 0
        var current = intervals[0]
        for interval in intervals.dropFirst() {
            if interval.start <= current.end {
                current.end = max(current.end, interval.end)
            } else {
                total += current.end.timeIntervalSince(current.start)
                current = interval
            }
        }
        total += current.end.timeIntervalSince(current.start)
        return total
    }
}
