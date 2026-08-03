//
//  AccountEntitlementTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Which accounts run under which entitlement. This partition is the paid gate:
//  `FetcherManager` builds fetchers from its `active` half, so anything in
//  `locked` stops polling, stops notifying, and drops out of the unread total.
//

import XCTest
@testable import Mail_Notifier

final class AccountEntitlementTests: XCTestCase {

    private func accounts(_ count: Int) -> [Account] {
        (1...count).map { Account(email: "user\($0)@example.com", type: .gmail) }
    }

    // MARK: Free tier

    func testFreeTierRunsTheFirstAccount() {
        let result = Accounts.partition(enabled: accounts(3), isEntitled: false)

        XCTAssertEqual(result.active.map(\.email), ["user1@example.com"])
        XCTAssertEqual(result.locked.map(\.email), ["user2@example.com", "user3@example.com"])
    }

    func testSingleAccountIsNeverLocked() {
        let result = Accounts.partition(enabled: accounts(1), isEntitled: false)

        XCTAssertEqual(result.active.count, 1)
        XCTAssertTrue(result.locked.isEmpty)
    }

    func testNoAccountsPartitionsToNothing() {
        let result = Accounts.partition(enabled: [], isEntitled: false)

        XCTAssertTrue(result.active.isEmpty)
        XCTAssertTrue(result.locked.isEmpty)
    }

    func testFreeSlotFollowsStoredOrder() {
        // Stored order is what the free slot follows, and "Use this one instead"
        // on a locked account moves it to the front. That is the only way to
        // choose which inbox stays free, so the partition must not sort or
        // shuffle.
        let reordered = [
            Account(email: "work@example.com", type: .outlook),
            Account(email: "personal@example.com", type: .gmail)
        ]
        let result = Accounts.partition(enabled: reordered, isEntitled: false)

        XCTAssertEqual(result.active.map(\.email), ["work@example.com"])
        XCTAssertEqual(result.locked.map(\.email), ["personal@example.com"])
    }

    // MARK: Subscribed

    func testSubscriberRunsEveryAccount() {
        let result = Accounts.partition(enabled: accounts(5), isEntitled: true)

        XCTAssertEqual(result.active.count, 5)
        XCTAssertTrue(result.locked.isEmpty)
    }

    func testLapsingRelocksEverythingPastTheFirst() {
        let all = accounts(4)

        XCTAssertTrue(Accounts.partition(enabled: all, isEntitled: true).locked.isEmpty)
        XCTAssertEqual(Accounts.partition(enabled: all, isEntitled: false).locked.count, 3)
    }

    // MARK: Limit

    func testLimitIsHonored() {
        let result = Accounts.partition(enabled: accounts(4), isEntitled: false, limit: 2)

        XCTAssertEqual(result.active.count, 2)
        XCTAssertEqual(result.locked.count, 2)
    }

    func testZeroLimitLocksEverything() {
        let result = Accounts.partition(enabled: accounts(2), isEntitled: false, limit: 0)

        XCTAssertTrue(result.active.isEmpty)
        XCTAssertEqual(result.locked.count, 2)
    }

    func testNegativeLimitIsTreatedAsZeroRatherThanCrashing() {
        // `prefix` traps on a negative count, and this number is one edit away
        // from a typo, so it's clamped rather than trusted.
        let result = Accounts.partition(enabled: accounts(2), isEntitled: false, limit: -1)

        XCTAssertTrue(result.active.isEmpty)
        XCTAssertEqual(result.locked.count, 2)
    }

    func testFreeLimitIsOne() {
        XCTAssertEqual(Accounts.freeAccountLimit, 1)
    }
}
