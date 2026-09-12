//
//  AccountExpansionStoreTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class AccountExpansionStoreTests: XCTestCase {

    private static let suiteName = "MailNotifierTests.AccountExpansion"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        AccountExpansionStore.defaults = defaults
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        AccountExpansionStore.defaults = .standard
        super.tearDown()
    }

    func testAnAccountNobodyHasTouchedStartsOpen() {
        XCTAssertTrue(AccountExpansionStore.isExpanded(email: "new@example.com"))
    }

    func testCollapsingIsRemembered() {
        AccountExpansionStore.setExpanded(false, email: "one@example.com")

        XCTAssertFalse(AccountExpansionStore.isExpanded(email: "one@example.com"))
    }

    func testReopeningIsRemembered() {
        AccountExpansionStore.setExpanded(false, email: "one@example.com")
        AccountExpansionStore.setExpanded(true, email: "one@example.com")

        XCTAssertTrue(AccountExpansionStore.isExpanded(email: "one@example.com"))
    }

    func testOneAccountCollapsingDoesNotCollapseTheOthers() {
        AccountExpansionStore.setExpanded(false, email: "one@example.com")

        XCTAssertFalse(AccountExpansionStore.isExpanded(email: "one@example.com"))
        XCTAssertTrue(AccountExpansionStore.isExpanded(email: "two@example.com"))
    }

    func testTheAddressIsMatchedRegardlessOfCase() {
        AccountExpansionStore.setExpanded(false, email: "Mixed@Example.com")

        XCTAssertFalse(AccountExpansionStore.isExpanded(email: "mixed@example.com"))
    }

    func testCollapsingTheSameAccountTwiceDoesNotStoreItTwice() {
        AccountExpansionStore.setExpanded(false, email: "one@example.com")
        AccountExpansionStore.setExpanded(false, email: "one@example.com")

        let stored = defaults.stringArray(forKey: AccountExpansionStore.storageKey) ?? []
        XCTAssertEqual(stored, ["one@example.com"])
    }
}
