//
//  MailNotifierApp.swift
//  Mail Notifier
//

//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit
import SwiftUI

extension Notification.Name {
    static let mailToReceived = Notification.Name("mailToReceived")
    static let openPreferencesWindow = Notification.Name("openPreferencesWindow")
}

@main
struct MailNotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
