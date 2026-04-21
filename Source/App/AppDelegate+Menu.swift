//
//  AppDelegate+Menu.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Right-click Menu

extension AppDelegate {
    func createRightClickMenu() -> NSMenu {
        let menu = NSMenu()

        let checkAllItem = NSMenuItem(
            title: NSLocalizedString("Check For New Mail", comment: ""),
            action: #selector(checkAllMails),
            keyEquivalent: ""
        )
        menu.addItem(checkAllItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: NSLocalizedString("Settings…", comment: ""),
                     action: #selector(showSettingsDrawer),
                     keyEquivalent: ",")
        menu.addItem(withTitle: NSLocalizedString("Check for Updates…", comment: ""),
                     action: #selector(checkForUpdates),
                     keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: NSLocalizedString("Quit Mail Notifier", comment: ""),
                     action: #selector(NSApp.terminate(_:)),
                     keyEquivalent: "q")

        return menu
    }
}
