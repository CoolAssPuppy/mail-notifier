//
//  AppSettingsTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class AppSettingsTests: XCTestCase {

    private static let suiteName = "MailNotifierTests.AppSettings"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        AppSettings.defaults = defaults
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        AppSettings.defaults = .standard
        super.tearDown()
    }

    // MARK: - Recent message count

    func testAFreshInstallShowsThreeRecentMessages() {
        XCTAssertEqual(AppSettings.shared.recentMessageCount, 3)
    }

    func testAChosenCountIsKept() {
        AppSettings.shared.recentMessageCount = 6

        XCTAssertEqual(AppSettings.shared.recentMessageCount, 6)
    }

    func testTheCountCannotBeSetBelowOne() {
        AppSettings.shared.recentMessageCount = 0

        XCTAssertEqual(AppSettings.shared.recentMessageCount, 1)
    }

    func testTheCountCannotBeSetAboveSeven() {
        AppSettings.shared.recentMessageCount = 99

        XCTAssertEqual(AppSettings.shared.recentMessageCount, 7)
    }

    func testAValueWrittenOutOfRangeBehindOurBackIsClampedOnRead() {
        defaults.set(40, forKey: AppSettings.recentMessageCountKey)

        XCTAssertEqual(AppSettings.shared.recentMessageCount, 7)
    }

    func testTheRangeNeverExceedsWhatTheFetcherKeeps() {
        XCTAssertLessThanOrEqual(AppSettings.recentMessageRange.upperBound,
                                 MessageFetcher.maximumMessagesStored)
    }

    // MARK: - Compact mode

    func testCompactModeIsOffForAFreshInstall() {
        XCTAssertFalse(AppSettings.shared.compactMode)
    }

    func testACompactModeChoiceIsKept() {
        AppSettings.shared.compactMode = true

        XCTAssertTrue(AppSettings.shared.compactMode)
    }

    func testStandardModeShowsAccountsWithoutUnreadMail() {
        AppSettings.shared.compactMode = false

        XCTAssertTrue(AppSettings.shared.shouldShowAccount(unreadCount: 0))
    }

    func testCompactModeHidesAccountsWithoutUnreadMail() {
        AppSettings.shared.compactMode = true

        XCTAssertFalse(AppSettings.shared.shouldShowAccount(unreadCount: 0))
        XCTAssertTrue(AppSettings.shared.shouldShowAccount(unreadCount: 1))
    }
}
