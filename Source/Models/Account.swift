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

    /// Human label used in subtitles, pickers, and status text.
    var displayLabel: String {
        switch self {
        case .gmail: return "Gmail"
        case .outlook: return "Outlook"
        }
    }

    /// Asset catalog name for the provider brand icon.
    var assetName: String {
        switch self {
        case .gmail: return "Gmail"
        case .outlook: return "Outlook"
        }
    }
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

    var baseURL: URL {
        switch type {
        case .gmail:
            var components = URLComponents()
            components.scheme = "https"
            components.host = "mail.google.com"
            let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? email
            components.percentEncodedPath = "/mail/b/\(encodedEmail)"
            return components.url ?? URL(string: "https://mail.google.com")!
        case .outlook:
            return URL(string: "https://outlook.live.com/mail/0/inbox")!
        }
    }

    var browser: Browser {
        Browser(identifier: openInBrowser)
    }

    var sound: Sound? {
        Sound(rawValue: notificationSound)
    }

    /// User-chosen label ("Work", "Supabase"). `nil` when unset.
    var friendlyName: String? {
        FriendlyNameStore.shared.name(for: email)
    }

    /// Friendly name when set, otherwise the raw email.
    var displayName: String {
        friendlyName ?? email
    }
}
