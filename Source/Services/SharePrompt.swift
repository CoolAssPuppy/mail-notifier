//
//  SharePrompt.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit

/// The two placements for the promo rotation and its share action.
enum ShareSource: String {
    /// The row under the menu bar popover controls.
    case menu
    /// The card under the account list in the main window.
    case settings
}

struct SharePromptStore {
    static let shareURL = URL(string: "https://www.strategicnerds.com/apps/mailnotifier")!
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6756112934")!

    func copyLink(from source: ShareSource, url: URL = Self.shareURL, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        Telemetry.capture(.shareLinkCopied, properties: ["source": source.rawValue])
    }
}
