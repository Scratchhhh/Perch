import Foundation

/// Quiet-hours math for the scheduled Do Not Disturb. Works in minutes-of-day so it is trivial to
/// test, and handles overnight ranges (e.g. 22:00 to 08:00).
public enum QuietHours {
    public static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    public static func contains(minuteOfDay minute: Int, start: Int, end: Int) -> Bool {
        guard start != end else { return false }
        if start < end {
            return minute >= start && minute < end
        }
        return minute >= start || minute < end
    }
}
