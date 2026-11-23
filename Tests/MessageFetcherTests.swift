//
//  MessageFetcherTests.swift
//  MailNotifierTests
//
//  Verifies the truth table of MessageFetcher.applyFetchResults — the pure
//  reducer at the core of every fetch cycle. Auth precedence wins, partial
//  successes preserve the other path's data, network failures don't trash
//  the user's view.
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class MessageFetcherTests: XCTestCase {

    private static let suiteName = "MailNotifierTests.MessageFetcher"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        Accounts.defaults = defaults
        Accounts.default = [Account(email: "fetcher@test.com", type: .gmail)]
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        Accounts.defaults = .standard
        super.tearDown()
    }

    private func makeFetcher() -> MessageFetcher {
        MessageFetcher(account: Account(email: "fetcher@test.com", type: .gmail))
    }

    private func makeMessages(_ count: Int) -> [Message] {
        (0..<count).map { i in
            Message(
                id: "msg-\(i)",
                email: "fetcher@test.com",
                type: .gmail,
                from: "Sender <s\(i)@example.com>",
                date: "",
                subject: "Subject \(i)",
                snippet: "",
                internalDate: TimeInterval(1_700_000_000_000 + i * 1000)
            )
        }
    }

    // MARK: - Auth precedence

    func testAuthFailureOnUnreadFlagsAuthErrorAndClearsState() {
        let fetcher = makeFetcher()
        fetcher.applyFetchResults(
            unreadResult: .failure(.authenticationRequired),
            messagesResult: .success(makeMessages(3))
        )
        XCTAssertTrue(fetcher.hasAuthError)
        XCTAssertEqual(fetcher.unreadMessagesCount, 0)
        XCTAssertEqual(fetcher.messages.count, 0)
    }

    func testAuthFailureOnMessagesFlagsAuthErrorAndClearsState() {
        let fetcher = makeFetcher()
        fetcher.applyFetchResults(
            unreadResult: .success(7),
            messagesResult: .failure(.authenticationRequired)
        )
        XCTAssertTrue(fetcher.hasAuthError)
        XCTAssertEqual(fetcher.unreadMessagesCount, 0)
        XCTAssertEqual(fetcher.messages.count, 0)
    }

    func testAuthFailureOnBothFlagsAuthError() {
        let fetcher = makeFetcher()
        fetcher.applyFetchResults(
            unreadResult: .failure(.authenticationRequired),
            messagesResult: .failure(.authenticationRequired)
        )
        XCTAssertTrue(fetcher.hasAuthError)
    }

    // MARK: - Both succeed

    func testBothSuccessUpdatesUnreadAndMessages() {
        let fetcher = makeFetcher()
        let messages = makeMessages(2)
        fetcher.applyFetchResults(
            unreadResult: .success(5),
            messagesResult: .success(messages)
        )
        XCTAssertFalse(fetcher.hasAuthError)
        XCTAssertEqual(fetcher.unreadMessagesCount, 5)
        XCTAssertEqual(fetcher.messages.count, 2)
    }

    // MARK: - Partial failures (non-auth)

    func testNetworkFailureOnMessagesPreservesUnreadCount() {
        let fetcher = makeFetcher()
        fetcher.applyFetchResults(
            unreadResult: .success(12),
            messagesResult: .failure(.networkError(URLError(.timedOut)))
        )
        // Should NOT be flagged as auth error — it's a transient network issue.
        XCTAssertFalse(fetcher.hasAuthError)
        // Unread count should still update from its successful path.
        XCTAssertEqual(fetcher.unreadMessagesCount, 12)
    }

    func testHttpFailureOnUnreadDoesNotClearMessages() {
        let fetcher = makeFetcher()
        let initial = makeMessages(3)
        // Seed messages via a clean prior call.
        fetcher.applyFetchResults(
            unreadResult: .success(0),
            messagesResult: .success(initial)
        )
        XCTAssertEqual(fetcher.messages.count, 3)

        // Now: unread fails (HTTP 500), messages also fails (HTTP 500).
        // Neither is auth. The previous messages should be preserved.
        fetcher.applyFetchResults(
            unreadResult: .failure(.httpError(statusCode: 500)),
            messagesResult: .failure(.httpError(statusCode: 500))
        )
        XCTAssertFalse(fetcher.hasAuthError)
        XCTAssertEqual(fetcher.messages.count, 3, "Transient HTTP failures must not clear cached messages")
    }

    // MARK: - hasNewMessages signal

    func testHasNewMessagesTrueOnFirstFetch() {
        let fetcher = makeFetcher()
        fetcher.applyFetchResults(
            unreadResult: .success(1),
            messagesResult: .success(makeMessages(1))
        )
        XCTAssertTrue(fetcher.hasNewMessages, "First successful fetch should signal new messages")
    }

    func testHasNewMessagesFalseWhenMessagesEmpty() {
        let fetcher = makeFetcher()
        fetcher.applyFetchResults(
            unreadResult: .success(0),
            messagesResult: .success([])
        )
        XCTAssertFalse(fetcher.hasNewMessages)
    }

    // MARK: - Last checked

    func testLastCheckedIsUnsetBeforeTheFirstCheck() {
        XCTAssertNil(makeFetcher().lastCheckedAt)
    }

    // MARK: - First check of a new account

    private func makeNewAccountFetcher(email: String = "fresh@test.com") -> MessageFetcher {
        var account = Account(email: email, type: .gmail)
        account.awaitingFirstCheck = true
        Accounts.default = [account]
        return MessageFetcher(account: account)
    }

    func testFirstCheckOfANewAccountAnnouncesTheUnreadCountOnce() {
        let fetcher = makeNewAccountFetcher()
        var announced: Int?
        // NotificationCenter matches `object` by identity, and a bridged String
        // literal is a different NSString from the account's email, so filter
        // on the value in the handler instead.
        let exp = expectation(forNotification: .accountFirstCheckCompleted, object: nil) { note in
            guard note.object as? String == "fresh@test.com" else { return false }
            announced = note.userInfo?["unreadCount"] as? Int
            return true
        }

        fetcher.applyFetchResults(unreadResult: .success(3), messagesResult: .success(makeMessages(3)))

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(announced, 3)
        XCTAssertFalse(fetcher.hasNewMessages, "Mail already in the inbox must not arrive as a burst of notifications")
        XCTAssertNil(Accounts.default.find(email: "fresh@test.com")?.awaitingFirstCheck)
        XCTAssertNil(fetcher.account.awaitingFirstCheck)
    }

    func testOnlyTheFirstCheckIsAnnounced() {
        let fetcher = makeNewAccountFetcher()
        fetcher.applyFetchResults(unreadResult: .success(0), messagesResult: .success([]))

        let exp = expectation(forNotification: .accountFirstCheckCompleted, object: nil)
        exp.isInverted = true
        fetcher.applyFetchResults(unreadResult: .success(1), messagesResult: .success(makeMessages(1)))
        wait(for: [exp], timeout: 0.3)
        XCTAssertTrue(fetcher.hasNewMessages, "Mail arriving after the first check notifies as usual")
    }

    func testAFailedFirstCheckWaitsForTheNextOne() {
        let fetcher = makeNewAccountFetcher()
        let exp = expectation(forNotification: .accountFirstCheckCompleted, object: nil)
        exp.isInverted = true

        fetcher.applyFetchResults(unreadResult: .success(2),
                                  messagesResult: .failure(.networkError(URLError(.timedOut))))
        wait(for: [exp], timeout: 0.3)
        XCTAssertEqual(Accounts.default.find(email: "fresh@test.com")?.awaitingFirstCheck, true)
    }

    func testAnExistingAccountIsNeverAnnounced() {
        let fetcher = makeFetcher()
        let exp = expectation(forNotification: .accountFirstCheckCompleted, object: nil)
        exp.isInverted = true
        fetcher.applyFetchResults(unreadResult: .success(1), messagesResult: .success(makeMessages(1)))
        wait(for: [exp], timeout: 0.3)
        XCTAssertTrue(fetcher.hasNewMessages)
    }
}
