//
//  MessageFetcher.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

final class MessageFetcher: NSObject {
    var account: Account
    private var provider: MailProvider
    private var timer: Timer?
    private(set) var hasAuthError = false

    /// Nil until the first check resolves, so the menu never says "Checked
    /// just now" about an account that has not been checked.
    private(set) var lastCheckedAt: Date?
    private(set) var hasNewMessages = false
    /// Set while the first check of a new account writes its messages. The
    /// mail already sitting in the inbox becomes the baseline rather than a
    /// burst of notifications; one "Connected" notification covers it.
    private var isApplyingFirstCheck = false

    private(set) var unreadMessagesCount = 0 {
        didSet {
            // Suppress no-op updates — every assignment otherwise triggers
            // a full menu-bar refresh even when the count is unchanged.
            guard oldValue != unreadMessagesCount else { return }
            NotificationCenter.default.post(name: .unreadCountUpdated, object: account.email)
        }
    }
    /// The window of recent mail kept per account. The Settings stepper for
    /// "Show recent messages" tops out below this, so the popover can never
    /// ask for more than has been fetched.
    static let maximumMessagesStored = 10

    private(set) var messages = [Message]() {
        didSet {
            // Same idea: only post when the message identifiers actually
            // changed. Comparing by id avoids comparing every message field.
            let oldIds = oldValue.map(\.id)
            let newIds = messages.map(\.id)
            let messagesChanged = oldIds != newIds

            if let newestMessage = messages.first {
                if isApplyingFirstCheck {
                    hasNewMessages = false
                } else if let newestMessageDate = account.newestMessageDate {
                    hasNewMessages = newestMessage.serverDate > newestMessageDate
                } else {
                    hasNewMessages = true
                }
                account.newestMessageDate = newestMessage.serverDate
                Accounts.default.update(account: account)
            } else {
                hasNewMessages = false
            }

            if messagesChanged {
                NotificationCenter.default.post(name: .messagesFetched, object: account.email)
            }
        }
    }

    init(account: Account) {
        self.account = account
        self.provider = Self.makeProvider(for: account)
    }

    @objc func fetch() {
        reschedule()
        provider.updateCredentials(from: account)
        performFetch()
    }

    func reschedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: account.checkInterval * 60,
            target: self,
            selector: #selector(fetch),
            userInfo: nil,
            repeats: false
        )
    }

    func cleanUp() {
        timer?.invalidate()
        provider.cleanUp()
    }

    private static func makeProvider(for account: Account) -> MailProvider {
        // Demo mode swaps the network for a script. Checked here rather than
        // inside each provider so no demo account can ever reach a real API.
        guard !DemoMode.isOnNow else { return DemoProvider(account: account) }

        switch account.type {
        case .gmail: return GmailProvider(account: account)
        case .outlook: return OutlookProvider(account: account)
        }
    }

    private func performFetch() {
        let group = DispatchGroup()
        let resultQueue = DispatchQueue(label: "com.strategicnerds.mailnotifier.fetchresult")

        var unreadResult: Result<Int, MailProviderError>?
        var messagesResult: Result<[Message], MailProviderError>?

        group.enter()
        provider.fetchUnreadCount { result in
            resultQueue.async {
                unreadResult = result
                group.leave()
            }
        }

        group.enter()
        provider.fetchMessages(limit: Self.maximumMessagesStored) { result in
            resultQueue.async {
                messagesResult = result
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.applyFetchResults(
                unreadResult: unreadResult ?? .failure(.parsingError("Missing unread count result")),
                messagesResult: messagesResult ?? .failure(.parsingError("Missing message list result"))
            )
        }
    }

    /// Reduces a pair of fetch results into the fetcher's published state.
    /// Internal access is intentional — exposed for unit testing.
    func applyFetchResults(
        unreadResult: Result<Int, MailProviderError>,
        messagesResult: Result<[Message], MailProviderError>
    ) {
        let isAuthFailure: Bool = {
            if case .failure(.authenticationRequired) = unreadResult { return true }
            if case .failure(.authenticationRequired) = messagesResult { return true }
            return false
        }()

        hasAuthError = isAuthFailure
        if isAuthFailure {
            unreadMessagesCount = 0
            messages = []
            return
        }

        if case .success(let count) = unreadResult {
            unreadMessagesCount = count
        }

        // The first check of a new account counts only when both paths
        // succeed; otherwise the next check gets another try.
        var firstCheckUnreadCount: Int?
        if account.awaitingFirstCheck == true,
           case .success(let count) = unreadResult,
           case .success = messagesResult {
            firstCheckUnreadCount = count
            isApplyingFirstCheck = true
        }

        if case .success(let msgs) = messagesResult {
            messages = msgs
        }
        isApplyingFirstCheck = false

        if let firstCheckUnreadCount {
            completeFirstCheck(unreadCount: firstCheckUnreadCount)
        }

        // Always advance lastCheckedAt when at least one path resolved.
        // Previously this only ran when messages succeeded, so the
        // "Last checked at hh:mm" footer froze on partial outages even
        // when unread count was successfully refreshed.
        lastCheckedAt = Date()
    }

    private func completeFirstCheck(unreadCount: Int) {
        account.awaitingFirstCheck = nil
        if var stored = Accounts.default.find(email: account.email) {
            stored.awaitingFirstCheck = nil
            stored.newestMessageDate = account.newestMessageDate
            var accounts = Accounts.default
            accounts.update(account: stored)
        }
        NotificationCenter.default.post(name: .accountFirstCheckCompleted,
                                        object: account.email,
                                        userInfo: ["unreadCount": unreadCount])
    }
}
