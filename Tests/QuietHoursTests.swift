import XCTest
@testable import Mail_Notifier

final class QuietHoursTests: XCTestCase {
    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private func calendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    func testDaytimeWindowIncludesStartAndExcludesEnd() {
        let quietHours = QuietHours(isEnabled: true, startMinute: 9 * 60, endMinute: 17 * 60)
        let lisbon = calendar("Europe/Lisbon")

        for (instant, expected) in [
            ("2026-01-15T08:59:00Z", false),
            ("2026-01-15T09:00:00Z", true),
            ("2026-01-15T16:59:00Z", true),
            ("2026-01-15T17:00:00Z", false)
        ] {
            XCTAssertEqual(quietHours.contains(date(instant), calendar: lisbon), expected, instant)
        }
    }

    func testOvernightWindowSpansMidnight() {
        let quietHours = QuietHours(isEnabled: true, startMinute: 22 * 60, endMinute: 8 * 60)
        let lisbon = calendar("Europe/Lisbon")

        for (instant, expected) in [
            ("2026-01-15T21:59:00Z", false),
            ("2026-01-15T22:00:00Z", true),
            ("2026-01-16T00:00:00Z", true),
            ("2026-01-16T07:59:00Z", true),
            ("2026-01-16T08:00:00Z", false)
        ] {
            XCTAssertEqual(quietHours.contains(date(instant), calendar: lisbon), expected, instant)
        }
    }

    func testDisabledAndEqualTimesSuppressNothing() {
        let lisbon = calendar("Europe/Lisbon")
        let midday = date("2026-01-15T12:00:00Z")

        XCTAssertFalse(QuietHours(isEnabled: false, startMinute: 9 * 60, endMinute: 17 * 60)
            .contains(midday, calendar: lisbon))
        XCTAssertFalse(QuietHours(isEnabled: true, startMinute: 12 * 60, endMinute: 12 * 60)
            .contains(midday, calendar: lisbon))
    }

    func testRepeatedLocalHourUsesWallClockTime() {
        let quietHours = QuietHours(isEnabled: true, startMinute: 60, endMinute: 120)
        let newYork = calendar("America/New_York")

        XCTAssertTrue(quietHours.contains(date("2026-11-01T05:30:00Z"), calendar: newYork))
        XCTAssertTrue(quietHours.contains(date("2026-11-01T06:30:00Z"), calendar: newYork))
        XCTAssertFalse(quietHours.contains(date("2026-11-01T07:00:00Z"), calendar: newYork))
    }

    func testDeliveryPolicySuppressesMailReceivedWhileTheMacWasAsleep() {
        let quietHours = QuietHours(isEnabled: true, startMinute: 22 * 60, endMinute: 8 * 60)
        let lisbon = calendar("Europe/Lisbon")

        XCTAssertTrue(quietHours.shouldSuppress(
            receivedAt: date("2026-01-15T23:30:00Z"),
            deliveredAt: date("2026-01-16T08:30:00Z"), calendar: lisbon
        ))
        XCTAssertTrue(quietHours.shouldSuppress(
            receivedAt: date("2026-01-15T17:00:00Z"),
            deliveredAt: date("2026-01-15T23:00:00Z"), calendar: lisbon
        ))
        XCTAssertFalse(quietHours.shouldSuppress(
            receivedAt: date("2026-01-15T17:00:00Z"),
            deliveredAt: date("2026-01-15T18:00:00Z"), calendar: lisbon
        ))
    }

    func testMissingReceivedTimeUsesDeliveryTime() {
        let quietHours = QuietHours(isEnabled: true, startMinute: 22 * 60, endMinute: 8 * 60)
        XCTAssertFalse(quietHours.shouldSuppress(
            receivedAt: nil, deliveredAt: date("2026-01-15T17:00:00Z"),
            calendar: calendar("Europe/Lisbon")
        ))
    }

    func testPickerTimeDoesNotShiftOnDaylightSavingChange() {
        let lisbon = calendar("Europe/Lisbon")
        let pickerDate = QuietHours.pickerDate(for: 90, calendar: lisbon)
        let components = lisbon.dateComponents([.hour, .minute], from: pickerDate)

        XCTAssertEqual(components.hour, 1)
        XCTAssertEqual(components.minute, 30)
    }

    func testMinutesAreClampedToOneDay() {
        XCTAssertEqual(QuietHours.normalizedMinute(-3), 0)
        XCTAssertEqual(QuietHours.normalizedMinute(1_500), 1_439)
    }
}
