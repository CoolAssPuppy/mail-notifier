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
    /// Minutes between checks. New accounts check every 5 minutes. Accounts
    /// saved earlier keep the interval stored in their JSON, because
    /// synthesized decoding reads the stored value and never this default.
    var checkInterval: Double = 5 {
        didSet {
            checkInterval = max(min(Double(Int(checkInterval)), 900), 1)
        }
    }
    var notificationEnabled = true
    var notificationSound = ""
    /// Empty means "whatever the system default browser is". It used to
    /// default to Safari's bundle id, which quietly overrode that choice for
    /// every account ever created. See `AccountMigrations`.
    var openInBrowser = Browser.defaultIdentifier
    var newestMessageDate: Date?
    /// Microsoft Entra tenant from the ID token's `tid` claim. Nil for Gmail
    /// and for Outlook accounts whose token has not been read yet.
    var tenantID: String?
    /// True from the moment a new account is added until its first complete
    /// check, which posts the one "Connected" notification. Nil afterwards and
    /// for every account added before this existed.
    var awaitingFirstCheck: Bool?
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
            return isWorkAccount
                ? URL(string: "https://outlook.office.com/mail/")!
                : URL(string: "https://outlook.live.com/mail/")!
        }
    }

    /// A Microsoft work or school account: its tenant is known and is not the
    /// consumer tenant that every personal Microsoft account shares.
    var isWorkAccount: Bool {
        guard type == .outlook, let tenantID else { return false }
        return MicrosoftTenant.isWorkOrSchool(tenantID: tenantID)
    }

    /// "Work" or "Personal" for a Microsoft account whose tenant is known.
    var microsoftAccountKindLabel: String? {
        guard type == .outlook, tenantID != nil else { return nil }
        return isWorkAccount
            ? NSLocalizedString("Work", comment: "Microsoft work or school account")
            : NSLocalizedString("Personal", comment: "Personal Microsoft account")
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
