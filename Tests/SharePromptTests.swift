//
//  SharePromptTests.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit
import XCTest
@testable import Mail_Notifier

/// Ways the share drawer could go wrong:
/// - It shows to someone with no accounts, who has nothing to recommend yet.
/// - It never shows on a fresh install that has accounts.
/// - Copying the link leaves the drawer coming back on every open.
/// - Closing the drawer leaves it coming back on every open.
/// - Copying from the Settings box leaves the drawer to ask again.
/// - The choice is lost on relaunch (a new store over the same defaults).
/// - The copied text is not the app page, or carries extra text.
final class SharePromptTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let name = "SharePromptTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("SharePromptTests.\(UUID().uuidString)"))
    }

    func testDrawerShowsForAnInstallWithAccounts() {
        XCTAssertTrue(SharePromptStore(defaults: makeDefaults()).shouldShowDrawer(hasAccounts: true))
    }

    func testDrawerStaysHiddenWithoutAccounts() {
        XCTAssertFalse(SharePromptStore(defaults: makeDefaults()).shouldShowDrawer(hasAccounts: false))
    }

    func testCopyingFromTheMenuRetiresTheDrawerAcrossRelaunch() {
        let defaults = makeDefaults()
        SharePromptStore(defaults: defaults).copyLink(from: .menu, to: makePasteboard())
        XCTAssertFalse(SharePromptStore(defaults: defaults).shouldShowDrawer(hasAccounts: true))
    }

    func testClosingTheDrawerRetiresItAcrossRelaunch() {
        let defaults = makeDefaults()
        SharePromptStore(defaults: defaults).dismissDrawer()
        XCTAssertFalse(SharePromptStore(defaults: defaults).shouldShowDrawer(hasAccounts: true))
    }

    func testCopyingFromSettingsAlsoRetiresTheDrawer() {
        let defaults = makeDefaults()
        SharePromptStore(defaults: defaults).copyLink(from: .settings, to: makePasteboard())
        XCTAssertFalse(SharePromptStore(defaults: defaults).shouldShowDrawer(hasAccounts: true))
    }

    func testCopyPutsOnlyTheAppPageOnThePasteboard() {
        let pasteboard = makePasteboard()
        SharePromptStore(defaults: makeDefaults()).copyLink(from: .menu, to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "https://www.strategicnerds.com/apps/mailnotifier")
    }
}
