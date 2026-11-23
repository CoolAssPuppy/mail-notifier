//
//  ConnectionStatus.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

/// The one notification posted after a new account's first complete check.
enum ConnectedNotice {
    static func title(unreadCount: Int) -> String {
        guard unreadCount > 0 else {
            return NSLocalizedString("Connected. You'll be notified about new mail.",
                                     comment: "First check of a new account, empty inbox")
        }
        return String(format: NSLocalizedString("Connected: %lld unread",
                                                comment: "First check of a new account"),
                      unreadCount)
    }
}

/// The status line under each account in the menu.
enum AccountStatusLine {
    static func text(hasAuthError: Bool,
                     lastCheckedAt: Date?,
                     now: Date = Date(),
                     locale: Locale = .current) -> String {
        if hasAuthError {
            return NSLocalizedString("Sign in again", comment: "Account status: signed out")
        }
        guard let lastCheckedAt else {
            return NSLocalizedString("Checking for mail", comment: "Account status: first check running")
        }
        if now.timeIntervalSince(lastCheckedAt) < 60 {
            return NSLocalizedString("Checked just now", comment: "Account status")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        let relative = formatter.localizedString(for: lastCheckedAt, relativeTo: now)
        return String(format: NSLocalizedString("Checked %@", comment: "Account status. %@ is like '2 minutes ago'"),
                      relative)
    }
}
