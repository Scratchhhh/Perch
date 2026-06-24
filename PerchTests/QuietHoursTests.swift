import XCTest
@testable import PerchCore

final class QuietHoursTests: XCTestCase {
    func testDaytimeRangeIsInclusiveOfStartExclusiveOfEnd() {
        let start = 9 * 60
        let end = 17 * 60
        XCTAssertTrue(QuietHours.contains(minuteOfDay: 9 * 60, start: start, end: end))
        XCTAssertTrue(QuietHours.contains(minuteOfDay: 12 * 60, start: start, end: end))
        XCTAssertFalse(QuietHours.contains(minuteOfDay: 17 * 60, start: start, end: end))
        XCTAssertFalse(QuietHours.contains(minuteOfDay: 8 * 60, start: start, end: end))
    }

    func testOvernightRangeWraps() {
        let start = 22 * 60
        let end = 8 * 60
        XCTAssertTrue(QuietHours.contains(minuteOfDay: 23 * 60, start: start, end: end))
        XCTAssertTrue(QuietHours.contains(minuteOfDay: 2 * 60, start: start, end: end))
        XCTAssertTrue(QuietHours.contains(minuteOfDay: 22 * 60, start: start, end: end))
        XCTAssertFalse(QuietHours.contains(minuteOfDay: 8 * 60, start: start, end: end))
        XCTAssertFalse(QuietHours.contains(minuteOfDay: 12 * 60, start: start, end: end))
    }

    func testZeroLengthRangeIsAlwaysOutside() {
        XCTAssertFalse(QuietHours.contains(minuteOfDay: 600, start: 600, end: 600))
    }

    func testMinuteOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 13, minute: 45)) ?? Date()
        XCTAssertEqual(QuietHours.minuteOfDay(date, calendar: calendar), 13 * 60 + 45)
    }
}
