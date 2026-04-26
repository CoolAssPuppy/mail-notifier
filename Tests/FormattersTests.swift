//
//  FormattersTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class FormattersTests: XCTestCase {

    func testRelativeLabelTodayShowsTime() {
        let now = Date()
        // A few hours earlier today.
        let earlier = now.addingTimeInterval(-3 * 3600)
        let label = Formatters.relativeLabel(for: earlier, reference: now)
        // Should be a time string ("3:42 PM" or "15:42") — not "Yesterday" or weekday.
        XCTAssertNotEqual(label, "Yesterday")
        XCTAssertFalse(label.isEmpty)
    }

    func testRelativeLabelYesterday() {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 26, hour: 12))!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: reference)!
        XCTAssertEqual(Formatters.relativeLabel(for: yesterday, reference: reference), "Yesterday")
    }

    func testRelativeLabelWithinPastWeekShowsWeekday() {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 26, hour: 12))!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: reference)!
        let label = Formatters.relativeLabel(for: threeDaysAgo, reference: reference)
        // 3 days before 2026-04-26 (Sun) is 2026-04-23 (Thu) — "Thu" in en_US.
        let weekday = Formatters.weekday.string(from: threeDaysAgo)
        XCTAssertEqual(label, weekday)
    }

    func testRelativeLabelOlderThanWeekShowsShortDate() {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 26, hour: 12))!
        let weeksAgo = Calendar.current.date(byAdding: .day, value: -45, to: reference)!
        let label = Formatters.relativeLabel(for: weeksAgo, reference: reference)
        // Should be MMM d format
        XCTAssertTrue(label.contains(" "), "Older dates should be 'MMM d' style; got '\(label)'")
    }
}
