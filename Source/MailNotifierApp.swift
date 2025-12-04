//
//  MailNotifierApp.swift
//  Mail Notifier
//
//  Created by James Chen on 2021/06/15.
//  Copyright © 2021 ashchan.com. All rights reserved.
//

import AppKit
import SwiftUI
import LaunchAtLogin

extension Notification.Name {
    static let mailToReceived = Notification.Name("mailToReceived")
    static let openPreferencesWindow = Notification.Name("openPreferencesWindow")
}

@main
struct MailNotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        LaunchAtLogin.migrateIfNeeded()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
