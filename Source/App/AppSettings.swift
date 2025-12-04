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
}

extension Notification.Name {
    static let showUnreadCountSettingChanged = Notification.Name("showUnreadCountSettingChanged")
}

extension AppSettings {
    var showUnreadCount: Bool {
        get {
            if let stored = UserDefaults.standard.object(forKey: Self.showUnreadCount) as? Bool {
                return stored
            }
            return true // Default to true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.showUnreadCount)
            showUnreadCountSettingChanged()
        }
    }

    var openSettingsOnStart: Bool {
        get {
            UserDefaults.standard.bool(forKey: Self.openSettingsOnStartKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.openSettingsOnStartKey)
        }
    }

    func showUnreadCountSettingChanged() {
        NotificationCenter.default.post(name: .showUnreadCountSettingChanged, object: nil)
    }
}
