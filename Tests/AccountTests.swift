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

    func testCheckIntervalDefaultsToFiveMinutesForNewAccounts() {
        let account = Account(email: "u@e.com", type: .gmail)
        XCTAssertEqual(account.checkInterval, 5)
    }

    func testStoredIntervalSurvivesTheNewDefault() throws {
        // An account saved before the default changed carries its interval in
        // the JSON. Decoding must keep it rather than fall back to 5.
        let json = #"{"email":"old@e.com","type":"gmail","enabled":true,"checkInterval":30,"notificationEnabled":true,"notificationSound":"","openInBrowser":""}"#
        let decoded = try JSONDecoder().decode(Account.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.checkInterval, 30)
        XCTAssertNil(decoded.tenantID)
        XCTAssertNil(decoded.awaitingFirstCheck)
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

    func testOutlookAccountWithUnknownTenantOpensOutlookLive() {
        let account = Account(email: "user@hotmail.com", type: .outlook)
        XCTAssertEqual(account.baseURL.absoluteString, "https://outlook.live.com/mail/")
    }

    func testPersonalMicrosoftAccountOpensOutlookLive() {
        var account = Account(email: "user@outlook.com", type: .outlook)
        account.tenantID = MicrosoftTenant.consumerTenantID
        XCTAssertFalse(account.isWorkAccount)
        XCTAssertEqual(account.baseURL.absoluteString, "https://outlook.live.com/mail/")
    }

    func testWorkMicrosoftAccountOpensOutlookOffice() {
        var account = Account(email: "user@contoso.com", type: .outlook)
        account.tenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"
        XCTAssertTrue(account.isWorkAccount)
        XCTAssertEqual(account.baseURL.absoluteString, "https://outlook.office.com/mail/")
    }

    func testTenantIDComparisonIgnoresCase() {
        var account = Account(email: "user@outlook.com", type: .outlook)
        account.tenantID = MicrosoftTenant.consumerTenantID.uppercased()
        XCTAssertFalse(account.isWorkAccount)
    }

    func testMicrosoftAccountKindLabel() {
        var work = Account(email: "a@contoso.com", type: .outlook)
        work.tenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"
        var personal = Account(email: "b@outlook.com", type: .outlook)
        personal.tenantID = MicrosoftTenant.consumerTenantID
        let unknown = Account(email: "c@outlook.com", type: .outlook)
        var gmail = Account(email: "d@gmail.com", type: .gmail)
        gmail.tenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"

        XCTAssertEqual(work.microsoftAccountKindLabel, "Work")
        XCTAssertEqual(personal.microsoftAccountKindLabel, "Personal")
        XCTAssertNil(unknown.microsoftAccountKindLabel)
        XCTAssertNil(gmail.microsoftAccountKindLabel)
        XCTAssertFalse(gmail.isWorkAccount)
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
        original.tenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"
        original.awaitingFirstCheck = true

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
        XCTAssertEqual(decoded.tenantID, original.tenantID)
        XCTAssertEqual(decoded.awaitingFirstCheck, true)
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
