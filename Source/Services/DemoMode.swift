//
//  DemoMode.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Screenshot mode. Fills the app with fake inboxes and canned mail so the menu
//  bar, the sidebar, and the notifications can be photographed without a real
//  inbox on screen.
//
//  Turn it on by right-clicking the "Current version" row in Settings > Updates.
//
//  The real accounts are copied to a backup key before the demo ones take their
//  place, and copied back when demo mode ends. It has to work this way rather
//  than by pointing `Accounts.defaults` at a second suite, because the sidebar
//  and the account pane read the list through `@AppStorage`, which always talks
//  to the standard suite. One storage location keeps every reader agreeing.
//
//  Only the accounts JSON moves. OAuth tokens live in the Keychain under the
//  account's email and are never read, rewritten, or deleted here, so a demo
//  session cannot cost anyone their authorization.
//

import Foundation

final class DemoMode: ObservableObject {
    static let shared = DemoMode()

    private static let flagKey = "demoModeEnabled"
    private static let backupKey = "accountsBeforeDemoMode"

    /// Read from outside the main actor by `MessageFetcher` (picking a provider)
    /// and `EntitlementManager` (unlocking the extra accounts), the same way
    /// `isEntitledNow` reads its record.
    nonisolated static var isOnNow: Bool {
        defaults.bool(forKey: flagKey)
    }

    @Published private(set) var isOn: Bool = DemoMode.isOnNow

    /// The flag, the backup, and the account list all live in one store, so the
    /// three can never disagree. In the app that store is `.standard`; tests
    /// point `Accounts.defaults` at a scratch suite and get this for free.
    private static var defaults: UserDefaults { Accounts.defaults }

    private var defaults: UserDefaults { Self.defaults }

    init() {}

    // MARK: - Switching

    /// Called during launch, before anything reads the account list.
    ///
    /// A demo session survives a quit, so this normally does nothing. It earns
    /// its place in the crash case: if the app died mid-demo with the flag
    /// already cleared, the real accounts are still sitting in the backup key
    /// and this puts them back.
    func applyAtLaunch() {
        guard !isOn else { return }
        restoreRealAccounts()
    }

    func toggle() {
        setOn(!isOn)
    }

    func setOn(_ on: Bool) {
        guard on != isOn else { return }

        if on {
            stashRealAccounts()
            Accounts.default = Accounts(DemoInbox.accounts)
        } else {
            restoreRealAccounts()
        }

        defaults.set(on, forKey: Self.flagKey)
        isOn = on

        announce()
    }

    /// Puts the demo inboxes back the way the script wrote them, for a demo that
    /// has been edited in the UI and wants to start over.
    func reseed() {
        guard isOn else { return }
        Accounts.default = Accounts(DemoInbox.accounts)
        announce()
    }

    /// The account list changed underneath everything. `AppDelegate` answers
    /// this by rebuilding the fetchers, which is what swaps every provider
    /// between the script and the network, and by redrawing the menu bar. The
    /// window needs no telling: its `@AppStorage` followed the write.
    private func announce() {
        NotificationCenter.default.post(name: .accountsReordered, object: nil)
    }

    // MARK: - The real accounts

    private func stashRealAccounts() {
        // Guarded so turning demo mode on twice can't overwrite the real list
        // with the demo one.
        guard defaults.string(forKey: Self.backupKey) == nil else { return }
        defaults.set(Accounts.default.rawValue, forKey: Self.backupKey)
    }

    private func restoreRealAccounts() {
        guard let stashed = defaults.string(forKey: Self.backupKey) else { return }
        defaults.set(stashed, forKey: Accounts.storageKey)
        defaults.removeObject(forKey: Self.backupKey)
    }
}
