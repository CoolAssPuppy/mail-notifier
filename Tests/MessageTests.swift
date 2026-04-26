//
//  MessageTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class MessageTests: XCTestCase {

    private func makeMessage(
        from: String = "Sender <sender@example.com>",
        type: AccountType = .gmail,
        snippet: String = "",
        internalDateMillis: TimeInterval = 0
    ) -> Message {
        Message(
            id: "m1",
            email: "user@example.com",
            type: type,
            from: from,
            date: "Wed, 01 Jan 2025 00:00:00 +0000",
            subject: "Hi",
            snippet: snippet,
            internalDate: internalDateMillis
        )
    }

    // MARK: - sender / senderEmail extraction

    func testSenderExtractsDisplayName() {
        let msg = makeMessage(from: "\"Jane Doe\" <jane@example.com>")
        XCTAssertEqual(msg.sender, "Jane Doe")
    }

    func testSenderHandlesUnquotedDisplayName() {
        let msg = makeMessage(from: "Jane Doe <jane@example.com>")
        XCTAssertEqual(msg.sender, "Jane Doe")
    }

    func testSenderEmailExtractsFromAngleBrackets() {
        let msg = makeMessage(from: "Jane Doe <jane@example.com>")
        XCTAssertEqual(msg.senderEmail, "jane@example.com")
    }

    func testSenderEmailLowercases() {
        let msg = makeMessage(from: "Jane Doe <Jane@Example.COM>")
        XCTAssertEqual(msg.senderEmail, "jane@example.com")
    }

    func testSenderEmailFallsBackToFullStringWhenNoBrackets() {
        let msg = makeMessage(from: "bare@example.com")
        XCTAssertEqual(msg.senderEmail, "bare@example.com")
    }

    // MARK: - URL construction

    func testGmailUrlContainsAccountAndMessageIds() {
        let url = Message.url(type: .gmail, email: "u@e.com", id: "abc123").absoluteString
        XCTAssertTrue(url.hasPrefix("https://mail.google.com/mail/u/"))
        XCTAssertTrue(url.contains("account_id=u@e.com") || url.contains("account_id=u%40e.com"))
        XCTAssertTrue(url.contains("message_id=abc123"))
    }

    func testOutlookUrlContainsEncodedMessageId() {
        let url = Message.url(type: .outlook, email: "u@e.com", id: "msg/with/slashes").absoluteString
        XCTAssertTrue(url.hasPrefix("https://outlook.live.com/mail/0/inbox/id/"))
        // Slashes in the message id must be percent-encoded so they don't
        // become extra path segments.
        XCTAssertTrue(url.contains("%2F"))
    }

    // MARK: - Date

    func testServerDateConvertsFromMillis() {
        let msg = makeMessage(internalDateMillis: 1_700_000_000_000)
        XCTAssertEqual(msg.serverDate, Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - Snippet decoding

    func testDecodedSnippetUnescapesAmpersand() {
        let msg = makeMessage(snippet: "Tom &amp; Jerry")
        XCTAssertEqual(msg.decodedSnippet, "Tom & Jerry")
    }

    func testDecodedSnippetUnescapesQuoteAndLt() {
        let msg = makeMessage(snippet: "&quot;Hello&quot; &lt;world&gt;")
        XCTAssertEqual(msg.decodedSnippet, "\"Hello\" <world>")
    }

    func testDecodedSnippetPassesThroughPlainText() {
        let msg = makeMessage(snippet: "no entities here")
        XCTAssertEqual(msg.decodedSnippet, "no entities here")
    }
}
