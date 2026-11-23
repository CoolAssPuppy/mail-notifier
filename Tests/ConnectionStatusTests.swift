//
//  ConnectionStatusTests.swift
//  MailNotifierTests
//
//  The words that prove an account is connected: the one notification after
//  its first check, and the status line each account shows in the menu.
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class ConnectionStatusTests: XCTestCase {

    // MARK: - Connected notification

    func testConnectedNoticeCountsUnreadMail() {
        XCTAssertEqual(ConnectedNotice.title(unreadCount: 3), "Connected: 3 unread")
        XCTAssertEqual(ConnectedNotice.title(unreadCount: 1), "Connected: 1 unread")
    }

    func testConnectedNoticeWithAnEmptyInbox() {
        XCTAssertEqual(ConnectedNotice.title(unreadCount: 0),
                       "Connected. You'll be notified about new mail.")
    }

    // MARK: - Status line

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let english = Locale(identifier: "en_US")

    private func line(authError: Bool = false, checked: Date?) -> String {
        AccountStatusLine.text(hasAuthError: authError, lastCheckedAt: checked, now: now, locale: english)
    }

    func testSignedOutAccountAsksToSignInAgain() {
        XCTAssertEqual(line(authError: true, checked: now), "Sign in again")
    }

    func testAccountNotCheckedYet() {
        XCTAssertEqual(line(checked: nil), "Checking for mail")
    }

    func testJustChecked() {
        XCTAssertEqual(line(checked: now.addingTimeInterval(-20)), "Checked just now")
    }

    func testCheckedMinutesAgo() {
        XCTAssertEqual(line(checked: now.addingTimeInterval(-120)), "Checked 2 minutes ago")
        XCTAssertEqual(line(checked: now.addingTimeInterval(-60)), "Checked 1 minute ago")
    }

    func testCheckedHoursAgo() {
        XCTAssertEqual(line(checked: now.addingTimeInterval(-3 * 3600)), "Checked 3 hours ago")
    }
}
