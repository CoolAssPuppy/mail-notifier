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

    private(set) var lastCheckedAt = Date()
    private(set) var hasNewMessages = false

    private(set) var unreadMessagesCount = 0 {
        didSet {
            NotificationCenter.default.post(name: .unreadCountUpdated, object: account.email)
        }
    }
    private let maximumMessagesStored = 10

    private(set) var messages = [Message]() {
        didSet {
            if let newestMessage = messages.first {
                if let newestMessageDate = account.newestMessageDate {
                    hasNewMessages = newestMessage.serverDate > newestMessageDate
                } else {
                    hasNewMessages = true
                }
                account.newestMessageDate = newestMessage.serverDate
                Accounts.default.update(account: account)
            } else {
                hasNewMessages = false
            }
            NotificationCenter.default.post(name: .messagesFetched, object: account.email)
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
        switch account.type {
        case .gmail: GmailProvider(account: account)
        case .outlook: OutlookProvider(account: account)
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
        provider.fetchMessages(limit: maximumMessagesStored) { result in
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

        switch messagesResult {
        case .success(let msgs):
            messages = msgs
            lastCheckedAt = Date()
        case .failure:
            break
        }
    }
}
