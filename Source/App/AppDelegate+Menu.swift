//
//  AppDelegate+Menu.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Menu Item Tags

private enum MenuItemTag: Int {
    case checkAll
    case separatorBelowCheck
    case separatorAboveAbout
}

// MARK: - Menu Creation

extension AppDelegate {
    func createMenu() -> NSMenu {
        let menu = NSMenu()

        let checkAllItem = NSMenuItem(
            title: NSLocalizedString("Check", comment: ""),
            action: #selector(checkAllMails),
            keyEquivalent: ""
        )
        checkAllItem.tag = MenuItemTag.checkAll.rawValue
        menu.addItem(checkAllItem)

        let separatorBelowCheck = NSMenuItem.separator()
        separatorBelowCheck.tag = MenuItemTag.separatorBelowCheck.rawValue
        menu.addItem(separatorBelowCheck)

        let separatorAbovePreferences = NSMenuItem.separator()
        separatorAbovePreferences.tag = MenuItemTag.separatorAboveAbout.rawValue
        menu.addItem(separatorAbovePreferences)

        menu.addItem(withTitle: NSLocalizedString("Preferences...", comment: ""), action: #selector(showPreferences), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("Quit Mail Notifier", comment: ""), action: #selector(NSApp.terminate(_:)), keyEquivalent: "")

        return menu
    }

    func updateMenu(_ menu: NSMenu) {
        guard let checkAllItem = menu.item(withTag: MenuItemTag.checkAll.rawValue) else { return }

        checkAllItem.title = NSLocalizedString(Accounts.default.count > 1 ? "Check For New Mail" : "Check", comment: "")
        checkAllItem.action = Accounts.default.enabled.isEmpty ? nil : #selector(checkAllMails)

        let indexBelowCheck = menu.indexOfItem(withTag: MenuItemTag.separatorBelowCheck.rawValue)
        let indexAboveAbout = menu.indexOfItem(withTag: MenuItemTag.separatorAboveAbout.rawValue)

        // Remove existing account items
        for index in ((indexBelowCheck + 1)..<indexAboveAbout).reversed() {
            menu.removeItem(at: index)
        }

        // Insert account items
        var offset = indexBelowCheck + 1
        if Accounts.default.count > 1 {
            for account in Accounts.default {
                menu.insertItem(createSubmenu(for: account), at: offset)
                offset += 1
            }
        } else {
            for item in createMenuItems(for: Accounts.default.first) {
                menu.insertItem(item, at: offset)
                offset += 1
            }
        }
    }
}

// MARK: - Account Menu Items

private extension AppDelegate {
    func createSubmenu(for account: Account) -> NSMenuItem {
        let submenu = NSMenu()
        let menuItem = NSMenuItem(title: account.email, action: #selector(openInbox(_:)), keyEquivalent: "")
        menuItem.representedObject = account.email
        menuItem.submenu = submenu

        submenu.addItem(withTitle: NSLocalizedString("Open Inbox", comment: ""), action: #selector(openInbox(_:)), keyEquivalent: "")

        let checkMailsItem = NSMenuItem(
            title: NSLocalizedString("Check", comment: ""),
            action: account.enabled ? #selector(checkMails(_:)) : nil,
            keyEquivalent: ""
        )
        submenu.addItem(checkMailsItem)
        submenu.addItem(NSMenuItem.separator())

        if let fetcher = fetcher(for: account.email), account.enabled {
            if fetcher.unreadMessagesCount > 0 {
                menuItem.title = "\(account.email) (\(fetcher.unreadMessagesCount))"
            }

            if fetcher.hasAuthError {
                let reauthorizeItem = NSMenuItem(
                    title: NSLocalizedString("Auth error - please reauthorize", comment: ""),
                    action: #selector(reauthorize(_:)),
                    keyEquivalent: ""
                )
                reauthorizeItem.representedObject = account
                submenu.addItem(reauthorizeItem)
            }

            for message in fetcher.messages {
                let messageItem = NSMenuItem(
                    title: "\(message.sender): \(message.subject)",
                    action: #selector(openMessage(_:)),
                    keyEquivalent: ""
                )
                messageItem.representedObject = message
                messageItem.toolTip = message.decodedSnippet
                submenu.addItem(messageItem)
            }

            submenu.addItem(NSMenuItem.separator())

            let lastChecked = fetcher.lastCheckedAt.formatted()
            submenu.addItem(NSMenuItem(
                title: NSLocalizedString("Last Checked:", comment: "") + " " + lastChecked,
                action: nil,
                keyEquivalent: ""
            ))
        }

        submenu.addItem(withTitle: NSLocalizedString(account.enabled ? "Disable Account" : "Enable Account", comment: ""), action: #selector(toggleAccount(_:)), keyEquivalent: "")

        // Set represented object for items without one
        for item in submenu.items where !item.isSeparatorItem && item.representedObject == nil {
            item.representedObject = account.email
        }

        return menuItem
    }

    func createMenuItems(for account: Account?) -> [NSMenuItem] {
        guard let account else { return [] }

        var items = [NSMenuItem]()

        items.append(NSMenuItem(
            title: NSLocalizedString("Open Inbox", comment: ""),
            action: #selector(openInbox(_:)),
            keyEquivalent: ""
        ))
        items.append(NSMenuItem.separator())

        if let fetcher = fetcher(for: account.email), account.enabled {
            if fetcher.hasAuthError {
                let reauthorizeItem = NSMenuItem(
                    title: NSLocalizedString("Auth error - please reauthorize", comment: ""),
                    action: #selector(reauthorize(_:)),
                    keyEquivalent: ""
                )
                reauthorizeItem.representedObject = account
                items.append(reauthorizeItem)
            }

            for message in fetcher.messages {
                let messageItem = NSMenuItem(
                    title: "\(message.sender): \(message.subject)",
                    action: #selector(openMessage(_:)),
                    keyEquivalent: ""
                )
                messageItem.representedObject = message
                messageItem.toolTip = message.decodedSnippet
                items.append(messageItem)
            }

            let lastChecked = fetcher.lastCheckedAt.formatted()
            items.append(NSMenuItem(
                title: NSLocalizedString("Last Checked:", comment: "") + " " + lastChecked,
                action: nil,
                keyEquivalent: ""
            ))

            items.append(NSMenuItem.separator())
        }

        items.append(NSMenuItem(
            title: NSLocalizedString(account.enabled ? "Disable Account" : "Enable Account", comment: ""),
            action: #selector(toggleAccount(_:)),
            keyEquivalent: ""
        ))
        items.append(NSMenuItem.separator())

        // Set represented object for items without one
        for item in items where !item.isSeparatorItem && item.representedObject == nil {
            item.representedObject = account.email
        }

        return items
    }
}
