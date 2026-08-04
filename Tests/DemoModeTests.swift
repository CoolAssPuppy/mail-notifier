//
//  DemoModeTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Demo mode replaces the account list with fake inboxes, so the thing worth
//  proving is that the real list always comes back. These tests run against a
//  scratch UserDefaults suite, never the real one.
//

import XCTest
@testable import Mail_Notifier

final class DemoModeTests: XCTestCase {

    private var suite: UserDefaults!
    private var suiteName: String!
    private var realDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.strategicnerds.MailNotifier.tests.demo.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
        realDefaults = Accounts.defaults
        Accounts.defaults = suite
    }

    override func tearDown() {
        Accounts.defaults = realDefaults
        suite.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: Fixtures

    private func realAccounts() -> Accounts {
        Accounts([
            Account(email: "me@work.example", type: .gmail),
            Account(email: "me@home.example", type: .outlook)
        ])
    }

    private func emails(_ accounts: Accounts) -> [String] {
        accounts.map(\.email)
    }

    // MARK: Turning it on

    func testTurningOnReplacesTheAccountListWithTheDemoInboxes() {
        Accounts.default = realAccounts()

        DemoMode().setOn(true)

        XCTAssertEqual(emails(Accounts.default), DemoInbox.accounts.map(\.email))
        XCTAssertTrue(DemoMode.isOnNow)
    }

    func testTurningOnKeepsTheRealAccountsRecoverable() {
        Accounts.default = realAccounts()

        DemoMode().setOn(true)

        XCTAssertEqual(suite.string(forKey: "accountsBeforeDemoMode"), realAccounts().rawValue)
    }

    // MARK: Turning it off

    func testTurningOffPutsTheRealAccountsBack() {
        Accounts.default = realAccounts()
        let demo = DemoMode()

        demo.setOn(true)
        demo.setOn(false)

        XCTAssertEqual(emails(Accounts.default), ["me@work.example", "me@home.example"])
        XCTAssertFalse(DemoMode.isOnNow)
    }

    func testTurningOffLeavesNoBackupBehind() {
        Accounts.default = realAccounts()
        let demo = DemoMode()

        demo.setOn(true)
        demo.setOn(false)

        XCTAssertNil(suite.string(forKey: "accountsBeforeDemoMode"))
    }

    func testTurningOnTwiceStillRestoresTheRealAccounts() {
        Accounts.default = realAccounts()
        let demo = DemoMode()

        demo.setOn(true)
        // A second instance is how a stale window or a re-entrant tap would
        // arrive. The guard on the backup is what stops the demo list from
        // being saved as if it were real.
        DemoMode().setOn(true)
        demo.setOn(false)

        XCTAssertEqual(emails(Accounts.default), ["me@work.example", "me@home.example"])
    }

    // MARK: Crash recovery

    func testLaunchRestoresRealAccountsWhenTheFlagIsOffButABackupSurvived() {
        suite.set(realAccounts().rawValue, forKey: "accountsBeforeDemoMode")
        Accounts.default = Accounts(DemoInbox.accounts)

        DemoMode().applyAtLaunch()

        XCTAssertEqual(emails(Accounts.default), ["me@work.example", "me@home.example"])
        XCTAssertNil(suite.string(forKey: "accountsBeforeDemoMode"))
    }

    func testLaunchLeavesAnActiveDemoSessionAlone() {
        suite.set(true, forKey: "demoModeEnabled")
        suite.set(realAccounts().rawValue, forKey: "accountsBeforeDemoMode")
        Accounts.default = Accounts(DemoInbox.accounts)

        DemoMode().applyAtLaunch()

        XCTAssertEqual(emails(Accounts.default), DemoInbox.accounts.map(\.email))
    }

    // MARK: The fake mail

    func testEveryDemoAccountHasMailToShow() {
        for account in DemoInbox.accounts {
            XCTAssertFalse(DemoInbox.messages(for: account.email).isEmpty,
                           "\(account.email) would render as an empty inbox")
        }
    }

    func testDemoMessagesArriveNewestFirst() {
        for account in DemoInbox.accounts {
            let dates = DemoInbox.messages(for: account.email).map(\.serverDate)
            XCTAssertEqual(dates, dates.sorted(by: >), "\(account.email) is out of order")
        }
    }

    func testDemoMessagesCarryTheirAccountProvider() {
        let outlook = DemoInbox.messages(for: "prashant@outlook.com")
        XCTAssertFalse(outlook.isEmpty)
        XCTAssertTrue(outlook.allSatisfy { $0.type == .outlook })
    }
}
