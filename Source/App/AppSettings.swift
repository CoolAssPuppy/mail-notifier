//
//  AppSettings.swift
//  Mail Notifier
//

//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

struct AppSettings {
    private init() {}
    static let shared = AppSettings()

    static let showUnreadCount = "settings.showUnreadCount"
    static let openSettingsOnStartKey = "settings.openSettingsOnStart"
    static let recentMessageCountKey = "settings.recentMessageCount"

    /// How many recent messages each account lists in the menu bar popover
    /// when nobody has chosen. Three was the hardcoded number before this was
    /// a setting, so leaving it alone changes nothing for anyone.
    static let defaultRecentMessageCount = 3

    /// The floor is one because a list of none is just the account row. The
    /// ceiling is seven because the fetcher only keeps ten messages per
    /// account and the popover has to stay a menu rather than an inbox.
    static let recentMessageRange = 1...7

    /// Tests point this at a scratch suite. The app uses the standard one,
    /// which is also where `@AppStorage` reads and writes.
    static var defaults: UserDefaults = .standard
}

extension AppSettings {
    var showUnreadCount: Bool {
        get {
            if let stored = Self.defaults.object(forKey: Self.showUnreadCount) as? Bool {
                return stored
            }
            return true // Default to true
        }
        nonmutating set {
            Self.defaults.set(newValue, forKey: Self.showUnreadCount)
            showUnreadCountSettingChanged()
        }
    }

    var openSettingsOnStart: Bool {
        get {
            Self.defaults.bool(forKey: Self.openSettingsOnStartKey)
        }
        nonmutating set {
            Self.defaults.set(newValue, forKey: Self.openSettingsOnStartKey)
        }
    }

    /// How many recent messages each account lists in the menu bar popover.
    ///
    /// Clamped on the way in and on the way out: the stepper in Settings can't
    /// leave the range, but `@AppStorage` writes the raw key and a value from
    /// an older build or a `defaults write` shouldn't be able to stretch the
    /// list past what the fetcher holds.
    var recentMessageCount: Int {
        get {
            guard let stored = Self.defaults.object(forKey: Self.recentMessageCountKey) as? Int else {
                return Self.defaultRecentMessageCount
            }
            return Self.clampRecentMessageCount(stored)
        }
        nonmutating set {
            Self.defaults.set(Self.clampRecentMessageCount(newValue), forKey: Self.recentMessageCountKey)
        }
    }

    static func clampRecentMessageCount(_ count: Int) -> Int {
        min(max(count, recentMessageRange.lowerBound), recentMessageRange.upperBound)
    }

    func showUnreadCountSettingChanged() {
        NotificationCenter.default.post(name: .showUnreadCountSettingChanged, object: nil)
    }
}
