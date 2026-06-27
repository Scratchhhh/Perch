import Foundation
import Observation
import PerchCore

/// User-facing toggles, persisted to UserDefaults. Observable so the UI and the mascot react live.
@MainActor
@Observable
final class PreferencesStore {
    private let defaults: UserDefaults

    private enum Key {
        static let sounds = "perch.sounds.enabled"
        static let mascot = "perch.mascot.enabled"
        static let mascotScale = "perch.mascot.scale"
        static let dndSchedule = "perch.dnd.scheduleEnabled"
        static let dndStart = "perch.dnd.startMinute"
        static let dndEnd = "perch.dnd.endMinute"
        static let projectRules = "perch.projectRules"
    }

    var soundsEnabled: Bool { didSet { defaults.set(soundsEnabled, forKey: Key.sounds) } }
    var mascotEnabled: Bool { didSet { defaults.set(mascotEnabled, forKey: Key.mascot) } }
    /// Size multiplier for the floating mascot (see `MascotSize`). Default 1.0 (medium).
    var mascotScale: Double { didSet { defaults.set(mascotScale, forKey: Key.mascotScale) } }
    var dndScheduleEnabled: Bool { didSet { defaults.set(dndScheduleEnabled, forKey: Key.dndSchedule) } }
    var dndStartMinute: Int { didSet { defaults.set(dndStartMinute, forKey: Key.dndStart) } }
    var dndEndMinute: Int { didSet { defaults.set(dndEndMinute, forKey: Key.dndEnd) } }

    /// Per-project delivery overrides, keyed by absolute project path. Persisted as JSON.
    var projectRules: [String: ProjectRule] { didSet { persistProjectRules() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        soundsEnabled = defaults.object(forKey: Key.sounds) as? Bool ?? true
        mascotEnabled = defaults.object(forKey: Key.mascot) as? Bool ?? false
        mascotScale = defaults.object(forKey: Key.mascotScale) as? Double ?? MascotSize.medium.scale
        dndScheduleEnabled = defaults.object(forKey: Key.dndSchedule) as? Bool ?? false
        dndStartMinute = defaults.object(forKey: Key.dndStart) as? Int ?? (22 * 60)
        dndEndMinute = defaults.object(forKey: Key.dndEnd) as? Int ?? (8 * 60)

        if let data = defaults.data(forKey: Key.projectRules),
           let decoded = try? JSONDecoder().decode([String: ProjectRule].self, from: data) {
            projectRules = decoded
        } else {
            projectRules = [:]
        }
    }

    func isInQuietHours(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard dndScheduleEnabled else { return false }
        let minute = QuietHours.minuteOfDay(date, calendar: calendar)
        return QuietHours.contains(minuteOfDay: minute, start: dndStartMinute, end: dndEndMinute)
    }

    /// The effective rule for a project, falling back to the permissive default when none is set.
    func rule(for projectPath: String?) -> ProjectRule {
        guard let projectPath, let rule = projectRules[projectPath] else { return .default }
        return rule
    }

    private func persistProjectRules() {
        guard let data = try? JSONEncoder().encode(projectRules) else { return }
        defaults.set(data, forKey: Key.projectRules)
    }
}
