//
//  AccountMigrations.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

/// One-shot rewrites of the stored account list, run at launch.
///
/// Each migration owns a `UserDefaults` flag so it runs once per install and
/// never fights a choice the person makes afterwards.
enum AccountMigrations {

    /// Set once the Safari rewrite below has run.
    static let safariBrowserChoiceKey = "migrations.safariBrowserChoiceCleared"

    /// Up to 3.6.3, `Account.openInBrowser` was born holding Safari's bundle
    /// id rather than the empty marker that means "ask the system". Every
    /// account ever added was therefore pinned to Safari, and clicking a
    /// message opened it there no matter what the person had chosen in System
    /// Settings. Reported by a user whose default is Chrome, who landed in a
    /// signed-out Safari every time.
    ///
    /// The default is fixed in `Account`, but that only helps accounts added
    /// from now on: `openInBrowser` is a stored key in the accounts JSON, and
    /// Swift's synthesized decoding throws on a missing key rather than
    /// falling back to the property's default. Existing accounts carry a
    /// literal "com.apple.Safari" on disk and have to be rewritten.
    ///
    /// This does take Safari away from the handful of people who picked it on
    /// purpose. They can pick it again, and it stays picked — the flag makes
    /// this a single pass.
    static func clearingSafariBrowserChoice(in accounts: [Account]) -> [Account] {
        accounts.map { account in
            guard account.openInBrowser == Browser.safariIdentifier else { return account }
            var updated = account
            updated.openInBrowser = Browser.defaultIdentifier
            return updated
        }
    }

    /// Runs every pending migration against the stored account list.
    ///
    /// Call before anything reads the accounts.
    static func run() {
        // Demo mode has swapped the fake inboxes into the account list and
        // parked the real ones in a backup key. Migrating now would rewrite
        // the fakes and burn the flag, leaving the real accounts on Safari
        // forever. Leave the flag unset and catch them on the next ordinary
        // launch.
        guard !DemoMode.isOnNow else { return }

        let defaults = Accounts.defaults
        guard !defaults.bool(forKey: safariBrowserChoiceKey) else { return }

        let stored = Array(Accounts.default)
        let migrated = clearingSafariBrowserChoice(in: stored)

        if migrated.map(\.openInBrowser) != stored.map(\.openInBrowser) {
            Accounts.default = Accounts(migrated)
            Log.app.info("Migrated \(migrated.count, privacy: .public) account(s) from a hardcoded Safari to the system default browser")
        }

        defaults.set(true, forKey: safariBrowserChoiceKey)
    }
}
