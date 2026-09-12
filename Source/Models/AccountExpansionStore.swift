//
//  AccountExpansionStore.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

/// Remembers which account cards in the menu bar popover are open.
///
/// The chevron state used to be plain `@State`, so every account came back
/// collapsed after a quit or a reboot and the person had to reopen each one to
/// see any mail. Now the choice survives the launch.
///
/// Collapsed addresses are what's stored, not expanded ones. That way an
/// account nobody has touched — a fresh install, a newly added inbox — is open,
/// which is what people expect from a menu that exists to show them their mail,
/// and no migration or first-launch write is needed to get there.
enum AccountExpansionStore {

    static let storageKey = "popover.collapsedAccounts"

    /// Tests point this at a scratch suite. The app uses the standard one.
    static var defaults: UserDefaults = .standard

    static func isExpanded(email: String) -> Bool {
        !collapsed.contains(normalize(email))
    }

    static func setExpanded(_ expanded: Bool, email: String) {
        let key = normalize(email)
        var emails = collapsed

        if expanded {
            emails.removeAll { $0 == key }
        } else {
            guard !emails.contains(key) else { return }
            emails.append(key)
        }

        defaults.set(emails, forKey: storageKey)
    }

    private static var collapsed: [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
