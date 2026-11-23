//
//  NotificationPermission.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation
import UserNotifications

/// Whether macOS lets Mail Notifier show notifications.
enum NotificationPermission: Equatable {
    case granted
    case denied
    case provisional
    case notDetermined

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized: self = .granted
        case .denied: self = .denied
        case .provisional: self = .provisional
        case .notDetermined: self = .notDetermined
        @unknown default: self = .granted
        }
    }

    static func current() async -> NotificationPermission {
        NotificationPermission(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
    }

    var analyticsValue: String {
        switch self {
        case .granted: return "granted"
        case .denied: return "denied"
        case .provisional: return "provisional"
        case .notDetermined: return "not_determined"
        }
    }

    /// The person turned notifications off, so new mail arrives silently
    /// until they turn them back on in System Settings.
    var isBlocked: Bool { self == .denied }

    /// System Settings > Notifications, opened on this app.
    static func settingsURL(bundleID: String = Bundle.main.bundleIdentifier ?? "com.strategicnerds.MailNotifierApp") -> URL {
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)")!
    }

    static let blockedMessage = NSLocalizedString("Notifications are off for Mail Notifier.",
                                                  comment: "Menu line when notifications are denied")
    static let openSettingsTitle = NSLocalizedString("Turn on", comment: "Opens notification settings")
}
