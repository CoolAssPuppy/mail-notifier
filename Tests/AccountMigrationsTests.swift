//
//  AccountMigrationsTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class AccountMigrationsTests: XCTestCase {

    private static let suiteName = "MailNotifierTests.AccountMigrations"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        Accounts.defaults = defaults
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        Accounts.defaults = .standard
        super.tearDown()
    }

    private func account(email: String, browser: String) -> Account {
        var account = Account(email: email, type: .gmail)
        account.openInBrowser = browser
        return account
    }

    // MARK: - The rewrite itself

    func testSafariAccountsFallBackToTheSystemDefaultBrowser() {
        let migrated = AccountMigrations.clearingSafariBrowserChoice(in: [
            account(email: "one@example.com", browser: Browser.safariIdentifier)
        ])

        XCTAssertEqual(migrated[0].openInBrowser, Browser.defaultIdentifier)
    }

    func testADeliberateNonSafariChoiceSurvives() {
        let migrated = AccountMigrations.clearingSafariBrowserChoice(in: [
            account(email: "chrome@example.com", browser: "com.google.Chrome"),
            account(email: "arc@example.com", browser: "company.thebrowser.Browser")
        ])

        XCTAssertEqual(migrated[0].openInBrowser, "com.google.Chrome")
        XCTAssertEqual(migrated[1].openInBrowser, "company.thebrowser.Browser")
    }

    func testAccountsAlreadyOnTheSystemDefaultAreLeftAlone() {
        let migrated = AccountMigrations.clearingSafariBrowserChoice(in: [
            account(email: "default@example.com", browser: Browser.defaultIdentifier)
        ])

        XCTAssertEqual(migrated[0].openInBrowser, Browser.defaultIdentifier)
    }

    func testEverythingElseAboutTheAccountIsUntouched() {
        var original = account(email: "keep@example.com", browser: Browser.safariIdentifier)
        original.checkInterval = 12
        original.notificationSound = "Ping"
        original.enabled = false

        let migrated = AccountMigrations.clearingSafariBrowserChoice(in: [original])[0]

        XCTAssertEqual(migrated.email, "keep@example.com")
        XCTAssertEqual(migrated.checkInterval, 12)
        XCTAssertEqual(migrated.notificationSound, "Ping")
        XCTAssertFalse(migrated.enabled)
    }

    // MARK: - Running it against the store

    func testRunRewritesTheStoredAccounts() {
        Accounts.default = Accounts([
            account(email: "one@example.com", browser: Browser.safariIdentifier),
            account(email: "two@example.com", browser: "com.google.Chrome")
        ])

        AccountMigrations.run()

        XCTAssertEqual(Accounts.default[0].openInBrowser, Browser.defaultIdentifier)
        XCTAssertEqual(Accounts.default[1].openInBrowser, "com.google.Chrome")
    }

    func testRunHappensOnceSoAChosenSafariIsNotOverwrittenTwice() {
        Accounts.default = Accounts([account(email: "one@example.com", browser: Browser.safariIdentifier)])
        AccountMigrations.run()

        // The person goes back and picks Safari on purpose.
        var chosen = Accounts.default[0]
        chosen.openInBrowser = Browser.safariIdentifier
        Accounts.default = Accounts([chosen])

        AccountMigrations.run()

        XCTAssertEqual(Accounts.default[0].openInBrowser, Browser.safariIdentifier)
    }

    func testRunSkipsDemoModeSoRealAccountsStillGetMigratedLater() {
        DemoMode.shared.setOn(true)
        defer { DemoMode.shared.setOn(false) }

        AccountMigrations.run()

        XCTAssertFalse(defaults.bool(forKey: AccountMigrations.safariBrowserChoiceKey))
    }
}
