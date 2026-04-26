//
//  AccountTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class AccountTests: XCTestCase {

    // MARK: - Identity

    func testIdMatchesEmail() {
        let account = Account(email: "user@example.com", type: .gmail)
        XCTAssertEqual(account.id, "user@example.com")
    }

    func testCheckIntervalDefaultsTo30() {
        let account = Account(email: "u@e.com", type: .gmail)
        XCTAssertEqual(account.checkInterval, 30)
    }

    // MARK: - checkInterval clamping

    func testCheckIntervalClampsAboveMaximum() {
        var account = Account(email: "u@e.com", type: .gmail)
        account.checkInterval = 5_000
        XCTAssertEqual(account.checkInterval, 900)
    }

    func testCheckIntervalClampsBelowMinimum() {
        var account = Account(email: "u@e.com", type: .gmail)
        account.checkInterval = -5
        XCTAssertEqual(account.checkInterval, 1)
    }

    func testCheckIntervalAcceptsValidValue() {
        var account = Account(email: "u@e.com", type: .gmail)
        account.checkInterval = 120
        XCTAssertEqual(account.checkInterval, 120)
    }

    // MARK: - baseURL

    func testGmailBaseURLPreservesEmailInPath() {
        let account = Account(email: "user+work@example.com", type: .gmail)
        let url = account.baseURL.absoluteString
        XCTAssertTrue(url.hasPrefix("https://mail.google.com/mail/b/"))
        // The "@" must not break the path structure — it stays literal because
        // the urlPathComponentAllowed set permits it. The "+" is also valid in
        // URL paths (only query strings interpret it as space), so it should
        // round-trip through to the path segment without being mangled.
        XCTAssertTrue(url.contains("user+work@example.com"))
    }

    func testGmailBaseURLEncodesSlashInEmailPathSegment() {
        // Pathological email containing "/" — must be percent-encoded so it
        // doesn't become an extra path segment.
        let account = Account(email: "u/ser@example.com", type: .gmail)
        XCTAssertTrue(account.baseURL.absoluteString.contains("%2F"))
    }

    func testOutlookBaseURLConstant() {
        let account = Account(email: "user@hotmail.com", type: .outlook)
        XCTAssertEqual(account.baseURL.absoluteString, "https://outlook.live.com/mail/0/inbox")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesAllFields() throws {
        var original = Account(email: "round@trip.com", type: .outlook)
        original.enabled = false
        original.checkInterval = 45
        original.notificationEnabled = false
        original.notificationSound = "blow"
        original.openInBrowser = "com.apple.Safari"
        original.newestMessageDate = Date(timeIntervalSince1970: 1_700_000_000)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Account.self, from: encoded)

        XCTAssertEqual(decoded.email, original.email)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.checkInterval, original.checkInterval)
        XCTAssertEqual(decoded.notificationEnabled, original.notificationEnabled)
        XCTAssertEqual(decoded.notificationSound, original.notificationSound)
        XCTAssertEqual(decoded.openInBrowser, original.openInBrowser)
        XCTAssertEqual(decoded.newestMessageDate, original.newestMessageDate)
    }

    // MARK: - AccountType

    func testAccountTypeDisplayLabels() {
        XCTAssertEqual(AccountType.gmail.displayLabel, "Gmail")
        XCTAssertEqual(AccountType.outlook.displayLabel, "Outlook")
    }

    func testAccountTypeAssetNames() {
        XCTAssertEqual(AccountType.gmail.assetName, "Gmail")
        XCTAssertEqual(AccountType.outlook.assetName, "Outlook")
    }

    func testAccountTypeAllCasesIsExhaustive() {
        XCTAssertEqual(AccountType.allCases.count, 2)
    }
}
