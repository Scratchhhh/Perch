import Foundation

/// One event reduced to what the weekly digest needs.
public struct DigestEvent: Sendable, Equatable {
    public let timestamp: Date
    public let isFinished: Bool
    public let demandsAttention: Bool
    public let projectName: String

    public init(timestamp: Date, isFinished: Bool, demandsAttention: Bool, projectName: String) {
        self.timestamp = timestamp
        self.isFinished = isFinished
        self.demandsAttention = demandsAttention
        self.projectName = projectName
    }
}

public struct ProjectTally: Sendable, Equatable, Identifiable {
    public let name: String
    public let count: Int
    public var id: String { name }

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

public struct WeeklyDigest: Sendable, Equatable {
    /// Completed turns (finishes) in the window.
    public let turns: Int
    /// Times an agent waited on you (attention prompts) in the window.
    public let timesWaited: Int
    /// Busiest projects by notable activity, most active first.
    public let topProjects: [ProjectTally]
    public let totalEvents: Int

    public init(turns: Int, timesWaited: Int, topProjects: [ProjectTally], totalEvents: Int) {
        self.turns = turns
        self.timesWaited = timesWaited
        self.topProjects = topProjects
        self.totalEvents = totalEvents
    }
}

/// Builds the local weekly summary from stored events. No network and no stored aggregate, so it
/// always reflects the current data.
public enum WeeklyDigestCalculator {
    public static func summarize(
        _ events: [DigestEvent],
        now: Date,
        calendar: Calendar = .current,
        days: Int = 7,
        topCount: Int = 3
    ) -> WeeklyDigest {
        let cutoff = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        let recent = events.filter { $0.timestamp >= cutoff && $0.timestamp <= now }

        let turns = recent.filter(\.isFinished).count
        let timesWaited = recent.filter(\.demandsAttention).count

        var counts: [String: Int] = [:]
        for event in recent where event.isFinished || event.demandsAttention {
            counts[event.projectName, default: 0] += 1
        }
        let topProjects = counts
            .map { ProjectTally(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .prefix(topCount)

        return WeeklyDigest(
            turns: turns,
            timesWaited: timesWaited,
            topProjects: Array(topProjects),
            totalEvents: recent.count
        )
    }
}
