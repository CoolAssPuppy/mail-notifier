//
//  AccountStoreTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class AccountStoreTests: XCTestCase {

    private static let suiteName = "MailNotifierTests.AccountStore"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Each test gets a clean UserDefaults suite so we never touch the user's
        // real preferences and tests can't leak state into each other.
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        Accounts.defaults = defaults
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        Accounts.defaults = .standard
        super.tearDown()
    }

    // MARK: - Round-trip

    func testEmptyRawValueDecodesToEmptyAccounts() {
        let accounts = Accounts(rawValue: "[]")
        XCTAssertEqual(accounts?.count, 0)
    }

    func testEncodingTheSameAccountsTwiceProducesTheSameString() {
        // Anything that stores, compares, or backs up the accounts JSON needs
        // the same accounts to serialize the same way every time.
        let accounts: Accounts = [
            Account(email: "a@one.com", type: .gmail),
            Account(email: "b@two.com", type: .outlook)
        ]

        XCTAssertEqual(accounts.rawValue, accounts.rawValue)
    }

    func testInvalidRawValueDecodesToNil() {
        XCTAssertNil(Accounts(rawValue: "{not json"))
    }

    func testRawValueRoundTripPreservesOrder() {
        let original: Accounts = [
            Account(email: "a@one.com", type: .gmail),
            Account(email: "b@two.com", type: .outlook),
            Account(email: "c@three.com", type: .gmail)
        ]
        let restored = Accounts(rawValue: original.rawValue)
        XCTAssertEqual(restored?.count, 3)
        XCTAssertEqual(restored?[0].email, "a@one.com")
        XCTAssertEqual(restored?[1].email, "b@two.com")
        XCTAssertEqual(restored?[2].email, "c@three.com")
    }

    // MARK: - find

    func testFindByEmailReturnsMatch() {
        let accounts: Accounts = [
            Account(email: "match@example.com", type: .gmail),
            Account(email: "other@example.com", type: .outlook)
        ]
        XCTAssertEqual(accounts.find(email: "match@example.com")?.email, "match@example.com")
    }

    func testFindByEmailReturnsNilForUnknown() {
        let accounts: Accounts = [Account(email: "real@example.com", type: .gmail)]
        XCTAssertNil(accounts.find(email: "fake@example.com"))
    }

    // MARK: - needsRescheduling / needsImmediateFetching

    func testNeedsReschedulingWhenIntervalChanges() {
        let old = Account(email: "u@e.com", type: .gmail)
        var new = old
        new.checkInterval = 60
        XCTAssertTrue(Accounts.needsRescheduling(oldValue: old, newValue: new))
    }

    func testNeedsReschedulingFalseWhenIntervalUnchanged() {
        let old = Account(email: "u@e.com", type: .gmail)
        var new = old
        new.notificationEnabled = false
        XCTAssertFalse(Accounts.needsRescheduling(oldValue: old, newValue: new))
    }

    func testNeedsImmediateFetchingWhenAccountReEnabled() {
        var old = Account(email: "u@e.com", type: .gmail)
        old.enabled = false
        var new = old
        new.enabled = true
        XCTAssertTrue(Accounts.needsImmediateFetching(oldValue: old, newValue: new))
    }

    func testNeedsImmediateFetchingFalseWhenAlreadyEnabled() {
        let old = Account(email: "u@e.com", type: .gmail)
        let new = old
        XCTAssertFalse(Accounts.needsImmediateFetching(oldValue: old, newValue: new))
    }

    // MARK: - Storing a finished sign-in

    private func expectAccountUpdated(email: String) -> (XCTestExpectation, () -> [AnyHashable: Any]?) {
        var captured: [AnyHashable: Any]?
        let exp = expectation(forNotification: .accountUpdated, object: nil) { note in
            guard (note.object as? Account)?.email == email else { return false }
            captured = note.userInfo
            return true
        }
        return (exp, { captured })
    }

    func testUpdateWithFetchNowAsksForAnImmediateFetch() {
        Accounts.default = [Account(email: "u@e.com", type: .gmail)]
        let (exp, info) = expectAccountUpdated(email: "u@e.com")

        var accounts = Accounts.default
        accounts.update(account: Account(email: "u@e.com", type: .gmail), fetchNow: true)

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(info()?["needsImmediateFetching"] as? Bool, true)
    }

    func testSigningInAgainToAnExistingAccountFetchesImmediately() {
        Accounts.default = [Account(email: "back@e.com", type: .outlook)]
        let (exp, info) = expectAccountUpdated(email: "back@e.com")

        let outcome = Accounts.storeAuthorized(email: "back@e.com", type: .outlook,
                                               tenantID: "72f988bf-86f1-41af-91ab-2d7cd011db47") { _ in }

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(outcome, .reauthorized)
        XCTAssertEqual(info()?["needsImmediateFetching"] as? Bool, true)
        XCTAssertEqual(Accounts.default.find(email: "back@e.com")?.tenantID,
                       "72f988bf-86f1-41af-91ab-2d7cd011db47")
    }

    func testANewAccountWaitsForItsFirstCheck() {
        let exp = expectation(forNotification: .accountAdded, object: nil)

        let outcome = Accounts.storeAuthorized(email: "new@outlook.com", type: .outlook,
                                               tenantID: MicrosoftTenant.consumerTenantID) { _ in }

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(outcome, .added)
        let stored = Accounts.default.find(email: "new@outlook.com")
        XCTAssertEqual(stored?.awaitingFirstCheck, true)
        XCTAssertEqual(stored?.tenantID, MicrosoftTenant.consumerTenantID)
        XCTAssertEqual(stored?.checkInterval, 5)
    }

    func testCredentialsAreAppliedBeforeTheAccountIsSaved() {
        var applied: [String] = []
        _ = Accounts.storeAuthorized(email: "cred@e.com", type: .gmail) { account in
            applied.append(account.email)
        }
        XCTAssertEqual(applied, ["cred@e.com"])
    }

    // MARK: - Filtering

    func testEnabledFiltersOutDisabled() {
        var enabled = Account(email: "on@e.com", type: .gmail)
        var disabled = Account(email: "off@e.com", type: .gmail)
        enabled.enabled = true
        disabled.enabled = false
        let accounts: Accounts = [enabled, disabled]
        let filtered = accounts.enabled
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.email, "on@e.com")
    }

    // MARK: - Static accessors with injected defaults

    func testDefaultPersistsAcrossRoundTrip() {
        var current = Accounts.default
        XCTAssertTrue(current.isEmpty)
        current.append(Account(email: "saved@example.com", type: .gmail))
        Accounts.default = current

        let reloaded = Accounts.default
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.email, "saved@example.com")
    }

    func testHasAccountsReflectsStore() {
        XCTAssertFalse(Accounts.hasAccounts)
        Accounts.default = [Account(email: "one@example.com", type: .gmail)]
        XCTAssertTrue(Accounts.hasAccounts)
    }

    // MARK: - Reordering

    func testReorderPersistsTheNewOrder() {
        var accounts: Accounts = [
            Account(email: "a@one.com", type: .gmail),
            Account(email: "b@two.com", type: .outlook),
            Account(email: "c@three.com", type: .gmail)
        ]
        accounts.save()

        // Drag the first row below the last one.
        accounts.reorder(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        XCTAssertEqual(Accounts.default.map(\.email), ["b@two.com", "c@three.com", "a@one.com"])
    }

    func testMovingTheLastAccountToTheFrontHandsItTheFreeSlot() {
        var accounts: Accounts = [
            Account(email: "a@one.com", type: .gmail),
            Account(email: "b@two.com", type: .outlook)
        ]
        accounts.save()

        accounts.reorder(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        XCTAssertEqual(Accounts.active(isEntitled: false).map(\.email), ["b@two.com"])
        XCTAssertEqual(Accounts.locked(isEntitled: false).map(\.email), ["a@one.com"])
    }
}
