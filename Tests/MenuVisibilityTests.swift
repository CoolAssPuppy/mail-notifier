//
//  MenuVisibilityTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit
import XCTest
@testable import Mail_Notifier

final class MenuVisibilityTests: XCTestCase {
    private static let suiteName = "MailNotifierTests.MenuVisibility"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        AppSettings.defaults = defaults
        Accounts.defaults = defaults
        Accounts.default = []
        FetcherManager.shared.rebuild()
    }

    override func tearDown() {
        Accounts.default = []
        FetcherManager.shared.rebuild()
        defaults.removePersistentDomain(forName: Self.suiteName)
        Accounts.defaults = .standard
        AppSettings.defaults = .standard
        super.tearDown()
    }

    func testPrettyDropdownShowsAnAccountWithoutUnreadMailInStandardMode() throws {
        let account = try seedAccount(unreadCount: 0)
        AppSettings.shared.compactMode = false

        let model = MenuBarPopoverModel()

        XCTAssertEqual(model.accountStates.map(\.account.email), [account.email])
        XCTAssertEqual(model.configuredAccountCount, 1)
    }

    func testPrettyDropdownShowsInboxZeroWhenCompactModeHasNoUnreadMail() throws {
        _ = try seedAccount(unreadCount: 0)
        AppSettings.shared.compactMode = true

        let model = MenuBarPopoverModel()

        XCTAssertTrue(model.accountStates.isEmpty)
        XCTAssertEqual(model.configuredAccountCount, 1)
        XCTAssertTrue(model.shouldShowInboxZero)
    }

    func testPrettyDropdownShowsAnUnreadAccountInCompactMode() throws {
        let account = try seedAccount(unreadCount: 1)
        AppSettings.shared.compactMode = true

        let model = MenuBarPopoverModel()

        XCTAssertEqual(model.accountStates.map(\.account.email), [account.email])
        XCTAssertFalse(model.shouldShowInboxZero)
    }

    func testPrettyDropdownRefreshesWhenCompactModeChanges() throws {
        let account = try seedAccount(unreadCount: 0)
        AppSettings.shared.compactMode = false
        let model = MenuBarPopoverModel()
        XCTAssertEqual(model.accountStates.map(\.account.email), [account.email])

        AppSettings.shared.compactMode = true
        NotificationCenter.default.post(name: .compactModeSettingChanged, object: nil)
        XCTAssertTrue(model.accountStates.isEmpty)
        XCTAssertTrue(model.shouldShowInboxZero)

        AppSettings.shared.compactMode = false
        NotificationCenter.default.post(name: .compactModeSettingChanged, object: nil)
        XCTAssertEqual(model.accountStates.map(\.account.email), [account.email])
        XCTAssertFalse(model.shouldShowInboxZero)
    }

    func testPrettyDropdownDoesNotShowInboxZeroWithoutConfiguredAccounts() {
        AppSettings.shared.compactMode = true

        let model = MenuBarPopoverModel()

        XCTAssertTrue(model.accountStates.isEmpty)
        XCTAssertEqual(model.configuredAccountCount, 0)
        XCTAssertFalse(model.shouldShowInboxZero)
    }

    func testClassicDropdownShowsAnAccountWithoutUnreadMailInStandardMode() throws {
        let account = try seedAccount(unreadCount: 0)
        AppSettings.shared.compactMode = false

        let menu = makeClassicMenu()

        XCTAssertEqual(menu.items.first?.title, account.displayName)
    }

    func testClassicDropdownShowsGrayInboxZeroRowWhenCompactModeHasNoUnreadMail() throws {
        _ = try seedAccount(unreadCount: 0)
        AppSettings.shared.compactMode = true

        let menu = makeClassicMenu()

        XCTAssertEqual(menu.items.first?.title, "Congrats! You are at Inbox Zero.")
        XCTAssertEqual(menu.items.first?.isEnabled, false)
        XCTAssertFalse(menu.items.contains { $0.title == "No accounts configured" })
        XCTAssertFalse(menu.items.contains { $0.title == "Add an account…" })
    }

    func testClassicDropdownShowsAnUnreadAccountInCompactMode() throws {
        let account = try seedAccount(unreadCount: 1)
        AppSettings.shared.compactMode = true

        let menu = makeClassicMenu()

        XCTAssertEqual(menu.items.first?.title, "\(account.displayName) (1)")
    }

    func testClassicDropdownKeepsTheNoAccountStateInCompactMode() {
        AppSettings.shared.compactMode = true

        let menu = makeClassicMenu()

        XCTAssertEqual(menu.items.first?.title, "No accounts configured")
        XCTAssertTrue(menu.items.contains { $0.title == "Add an account…" })
    }

    private func seedAccount(unreadCount: Int) throws -> Account {
        let account = Account(email: "menu@example.com", type: .gmail)
        Accounts.default = [account]
        FetcherManager.shared.rebuild()

        let fetcher = try XCTUnwrap(FetcherManager.shared.fetcher(for: account.email))
        fetcher.applyFetchResults(
            unreadResult: .success(unreadCount),
            messagesResult: .success([])
        )
        return account
    }

    private func makeClassicMenu() -> NSMenu {
        ClassicMenuBuilder.makeMenu(
            accounts: Accounts.default,
            fetcherManager: FetcherManager.shared,
            actions: .init(
                openInbox: { _ in },
                openMessage: { _ in },
                reauthorize: { _ in },
                checkAll: {},
                openWindow: {},
                openSettings: {},
                subscribe: {},
                quit: {}
            )
        )
    }
}
