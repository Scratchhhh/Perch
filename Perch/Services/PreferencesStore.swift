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
        static let dndSchedule = "perch.dnd.scheduleEnabled"
        static let dndStart = "perch.dnd.startMinute"
        static let dndEnd = "perch.dnd.endMinute"
    }

    var soundsEnabled: Bool { didSet { defaults.set(soundsEnabled, forKey: Key.sounds) } }
    var mascotEnabled: Bool { didSet { defaults.set(mascotEnabled, forKey: Key.mascot) } }
    var dndScheduleEnabled: Bool { didSet { defaults.set(dndScheduleEnabled, forKey: Key.dndSchedule) } }
    var dndStartMinute: Int { didSet { defaults.set(dndStartMinute, forKey: Key.dndStart) } }
    var dndEndMinute: Int { didSet { defaults.set(dndEndMinute, forKey: Key.dndEnd) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        soundsEnabled = defaults.object(forKey: Key.sounds) as? Bool ?? true
        mascotEnabled = defaults.object(forKey: Key.mascot) as? Bool ?? false
        dndScheduleEnabled = defaults.object(forKey: Key.dndSchedule) as? Bool ?? false
        dndStartMinute = defaults.object(forKey: Key.dndStart) as? Int ?? (22 * 60)
        dndEndMinute = defaults.object(forKey: Key.dndEnd) as? Int ?? (8 * 60)
    }

    func isInQuietHours(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard dndScheduleEnabled else { return false }
        let minute = QuietHours.minuteOfDay(date, calendar: calendar)
        return QuietHours.contains(minuteOfDay: minute, start: dndStartMinute, end: dndEndMinute)
    }
}
