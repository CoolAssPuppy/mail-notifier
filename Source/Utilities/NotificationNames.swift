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

    // MARK: Subscription Events
    /// The cached entitlement changed. Fetchers are built from the entitlement,
    /// so this has to reach `FetcherManager` and the menu bar, not only the
    /// SwiftUI views bound to `EntitlementManager.record`.
    static let entitlementChanged = Notification.Name("entitlementChanged")
    /// Something tried to do a paid thing without a subscription. The object is
    /// the `PaywallTrigger` that asked, which decides the sheet's wording.
    static let showPaywall = Notification.Name("showPaywall")

    // MARK: UI Events
    static let openSettingsDrawer = Notification.Name("openSettingsDrawer")
    static let friendlyNamesChanged = Notification.Name("friendlyNamesChanged")
}
