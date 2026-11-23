//
//  SharePrompt.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit

/// Where the person copied the share link from.
enum ShareSource: String {
    /// The drawer under the menu bar popover.
    case menu
    /// The dashed box under the account list in the main window.
    case settings
}

/// The "Help us grow" prompt: what it copies and whether the popover drawer
/// still asks.
///
/// The drawer opens under the popover until the person copies the link or
/// closes it, from either place. The box in the main window stays, since it
/// sits out of the way.
struct SharePromptStore {
    static let shareURL = URL(string: "https://www.strategicnerds.com/apps/mailnotifier")!
    static let retiredKey = "sharePromptDrawerRetired"

    var defaults: UserDefaults = .standard

    func shouldShowDrawer(hasAccounts: Bool) -> Bool {
        hasAccounts && !defaults.bool(forKey: Self.retiredKey)
    }

    func copyLink(from source: ShareSource, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(Self.shareURL.absoluteString, forType: .string)
        defaults.set(true, forKey: Self.retiredKey)
        Telemetry.capture(.shareLinkCopied, properties: ["source": source.rawValue])
    }

    func dismissDrawer() {
        defaults.set(true, forKey: Self.retiredKey)
        Telemetry.capture(.sharePromptDismissed)
    }
}
