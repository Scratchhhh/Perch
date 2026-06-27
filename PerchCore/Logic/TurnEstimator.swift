import Foundation

/// Typical-turn statistics derived from the gaps between a session's events.
public struct TurnStats: Sendable, Equatable {
    /// Number of inter-event gaps the stats are based on.
    public let sampleCount: Int
    /// Median gap — the "usually about this long" figure shown for active sessions.
    public let median: TimeInterval
    /// 95th-percentile gap — used as a "this is unusually long" stuck threshold.
    public let p95: TimeInterval

    public init(sampleCount: Int, median: TimeInterval, p95: TimeInterval) {
        self.sampleCount = sampleCount
        self.median = median
        self.p95 = p95
    }
}

/// Estimates how long a session's turns usually take from the spacing of its past events. Pure so
/// it can be tested and run off the main thread; the app feeds it a session's event timestamps.
public enum TurnEstimator {
    public static func turnStats(eventTimes: [Date], minimumSamples: Int = 3) -> TurnStats? {
        let gaps = positiveGaps(eventTimes)
        guard gaps.count >= minimumSamples,
              let median = median(gaps),
              let p95 = percentile(0.95, gaps) else { return nil }
        return TurnStats(sampleCount: gaps.count, median: median, p95: p95)
    }

    /// Positive gaps between consecutive (sorted) timestamps; zero/negative gaps (duplicates) drop.
    public static func positiveGaps(_ times: [Date]) -> [TimeInterval] {
        let sorted = times.sorted()
        guard sorted.count > 1 else { return [] }
        var gaps: [TimeInterval] = []
        for index in 1..<sorted.count {
            let gap = sorted[index].timeIntervalSince(sorted[index - 1])
            if gap > 0 { gaps.append(gap) }
        }
        return gaps
    }

    public static func median(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    /// Nearest-rank percentile (`p` in 0...1).
    public static func percentile(_ p: Double, _ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let rank = Int((p * Double(sorted.count)).rounded(.up))
        let index = min(max(rank - 1, 0), sorted.count - 1)
        return sorted[index]
    }
}

/// Decides when an actively-working session has been quiet for unusually long. Hooks can't report
/// "stuck", so this is inferred: a session is flagged once it's been working past a threshold based
/// on its own usual turn length (P95), but never below a sensible floor to avoid false alarms on
/// agents that normally finish in seconds.
public enum StuckPolicy {
    /// Never flag a session as stuck before this much silence, regardless of its (possibly tiny)
    /// historical turns. Long-running tasks are normal; five minutes of total silence is the floor.
    public static let floorThreshold: TimeInterval = 5 * 60

    public static func threshold(turnStats: TurnStats?, floor: TimeInterval = floorThreshold) -> TimeInterval {
        guard let turnStats else { return floor }
        // 1.5× the usual worst case gives headroom over normal variation before we cry wolf.
        return max(floor, turnStats.p95 * 1.5)
    }

    public static func isStuck(workingSince: Date, now: Date, threshold: TimeInterval) -> Bool {
        now.timeIntervalSince(workingSince) > threshold
    }
}
