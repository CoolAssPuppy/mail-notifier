//
//  FetcherManager.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

/// Manages MessageFetcher instances for all enabled accounts.
final class FetcherManager {
    static let shared = FetcherManager()

    private var fetchers: [String: MessageFetcher] = [:]

    private init() {}

    /// Returns the fetcher for a specific email account.
    func fetcher(for email: String?) -> MessageFetcher? {
        guard let email else { return nil }
        return fetchers[email]
    }

    /// Returns all current fetchers.
    var allFetchers: [MessageFetcher] {
        Array(fetchers.values)
    }

    /// Returns the total unread message count across all accounts.
    var totalUnreadCount: Int {
        fetchers.values.reduce(0) { $0 + $1.unreadMessagesCount }
    }

    /// The subscription gate, read without hopping to the main actor. `rebuild`
    /// runs from notification handlers on whatever thread posted them, and this
    /// reads the same persisted record `EntitlementManager` publishes.
    private var isEntitled: Bool {
        EntitlementManager.isEntitledNow()
    }

    /// Rebuilds the fetchers dictionary based on the accounts currently allowed
    /// to run.
    ///
    /// This is the run gate for the paid multi-account plan. Everything a locked
    /// account would otherwise do goes through a fetcher, so withholding the
    /// fetcher stops the polling, the unread count, the notifications, and the
    /// menu rows in one move.
    func rebuild() {
        let accounts = Accounts.active(isEntitled: isEntitled)

        // Remove fetchers for deleted/disabled accounts
        for email in fetchers.keys where !accounts.contains(where: { $0.email == email }) {
            fetchers[email]?.cleanUp()
            fetchers[email] = nil
        }

        // Add or update fetchers for enabled accounts
        for account in accounts {
            if let existingFetcher = fetchers[account.email] {
                existingFetcher.account = account
            } else {
                fetchers[account.email] = MessageFetcher(account: account)
            }
        }
    }

    /// Updates fetchers and optionally fetches for a specific account.
    func update(fetchingAccount: Account? = nil) {
        rebuild()

        if let fetchingAccount {
            fetcher(for: fetchingAccount.email)?.fetch()
        } else {
            fetchers.values.forEach { $0.fetch() }
        }
    }

    /// Triggers a fetch for all accounts.
    func checkAll() {
        fetchers.values.forEach { $0.fetch() }
    }
}
