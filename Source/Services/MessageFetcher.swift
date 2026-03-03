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

        provider.fetchUnreadCount { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let count):
                hasAuthError = false
                unreadMessagesCount = count
            case .failure(.authenticationRequired):
                hasAuthError = true
                unreadMessagesCount = 0
                messages = []
            case .failure:
                hasAuthError = true
            }
        }

        provider.fetchMessages(limit: maximumMessagesStored) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msgs):
                hasAuthError = false
                messages = msgs
                lastCheckedAt = Date()
            case .failure(.authenticationRequired):
                hasAuthError = true
                messages = []
            case .failure:
                hasAuthError = true
            }
        }
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
}
