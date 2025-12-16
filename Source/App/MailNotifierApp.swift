//
//  MailNotifierApp.swift
//  Mail Notifier
//

//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit
import SwiftUI

@main
struct MailNotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
