//
//  Account.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

enum AccountType: String, Codable, CaseIterable {
    case gmail
    case outlook
}

struct Account: Codable {
    var email: String
    var type: AccountType = .gmail
    var enabled = true
    var checkInterval: Double = 30 {
        didSet {
            checkInterval = max(min(Double(Int(checkInterval)), 900), 1)
        }
    }
    var notificationEnabled = true
    var notificationSound = ""
    var openInBrowser = Browser.safariIdentifier
    var newestMessageDate: Date?
}

extension Account: Identifiable, Hashable {
    var id: String { email }

    var baseUrl: String {
        switch type {
        case .gmail:
            return "https://mail.google.com/mail/b/\(email)"
        case .outlook:
            return "https://outlook.live.com/mail/0/inbox"
        }
    }

    var browser: Browser {
        Browser(identifier: openInBrowser)
    }

    var sound: Sound? {
        Sound(rawValue: notificationSound)
    }
}
