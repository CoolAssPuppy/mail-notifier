//
//  NotificationNames.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    // MARK: Account Events
    static let accountAdded = Notification.Name("accountAdded")
    static let accountDeleted = Notification.Name("accountDeleted")
    static let accountUpdated = Notification.Name("accountUpdated")
    static let accountsReordered = Notification.Name("accountsReordered")

    // MARK: Message Events
    static let unreadCountUpdated = Notification.Name("unreadCountUpdated")
    static let messagesFetched = Notification.Name("messagesFetched")

    // MARK: Settings Events
    static let showUnreadCountSettingChanged = Notification.Name("showUnreadCountSettingChanged")

    // MARK: URL Events
    static let mailToReceived = Notification.Name("mailToReceived")
    static let openPreferencesWindow = Notification.Name("openPreferencesWindow")
}
