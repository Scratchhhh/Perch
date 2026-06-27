import Foundation

public struct EventStat: Sendable, Equatable {
    public let timestamp: Date
    public let acknowledgedAt: Date?
    /// Worth showing in history/streak/histogram (a finish or an attention prompt).
    public let isNotable: Bool
    /// Actually demanded the user's attention (needs-input / permission / blocked). Only these
    /// count toward focus saved — a `.finished` event never kept anyone waiting at the keyboard.
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
    /// Minutes of focus Perch protected, measured as the union of "waiting on you" intervals.
    public let focusSavedMinutes: Int
    /// How many attention prompts the user closed through Perch (acknowledged), i.e. context
    /// switches that didn't require babysitting the terminal.
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
/// "Focus saved" is the honest version of the old "waiting saved": instead of summing every
/// event's gap (which double-counted parallel agents and counted finishes that never required
/// attention), it takes the **union of the intervals during which an agent was actually waiting
/// on you**. Two agents waiting through the same lunch break count that lunch once, not twice.
public enum StatsCalculator {
    /// A single waiting interval can't credit more than this. Past ~30 min you've clearly walked
    /// away on your own terms — Perch isn't "saving" you from staring at a prompt, you've already
    /// context-switched. The old 2h cap is what let a few overnight gaps balloon the headline
    /// number into hundreds of hours.
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

    /// Builds capped `[start, end]` waiting intervals from acknowledged attention events, merges
    /// any that overlap or touch, and returns the total length of the merged set. Merging is what
    /// stops parallel agents from triple-counting the same wall-clock minutes.
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
                // Overlapping or touching — extend the running interval instead of adding it.
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
