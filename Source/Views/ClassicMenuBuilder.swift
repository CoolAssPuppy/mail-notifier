//
//  ClassicMenuBuilder.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Closure-backed menu item

/// `NSMenuItem.target` is a weak reference, so an item that points at a
/// short-lived helper object would silently stop firing. Targeting itself
/// keeps the handler alive exactly as long as the menu that owns the item.
private final class ClassicMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func invoke() {
        handler()
    }
}

// MARK: - Builder

/// Builds the classic dropdown: one item per account, a submenu of unread
/// subjects, and the icon strip at the bottom.
enum ClassicMenuBuilder {
    struct Actions {
        var openInbox: (Account) -> Void
        var openMessage: (Message) -> Void
        var reauthorize: (Account) -> Void
        var checkAll: () -> Void
        var openWindow: () -> Void
        var openSettings: () -> Void
        /// Opens the main window with the paywall up. An `NSMenu` row has no
        /// room to make the case, so a locked account hands off.
        var subscribe: () -> Void
        var quit: () -> Void
    }

    private static let maximumSubjectLength = 64
    private static let providerIconSize = NSSize(width: 14, height: 14)

    static func makeMenu(accounts: Accounts,
                         fetcherManager: FetcherManager,
                         lockedEmails: Set<String> = [],
                         actions: Actions) -> NSMenu {
        let menu = NSMenu()
        // Items here are enabled explicitly. Automatic enabling walks the
        // responder chain and would grey out everything in a menu owned by an
        // .accessory app with no key window.
        menu.autoenablesItems = false

        if accounts.isEmpty {
            appendEmptyState(to: menu, actions: actions)
        } else {
            for account in accounts {
                menu.addItem(accountItem(for: account,
                                         fetcher: fetcherManager.fetcher(for: account.email),
                                         isLocked: lockedEmails.contains(account.email),
                                         actions: actions))
            }
        }

        menu.addItem(.separator())
        menu.addItem(footerItem(actions: actions))

        return menu
    }

    // MARK: Empty state

    private static func appendEmptyState(to menu: NSMenu, actions: Actions) {
        let placeholder = NSMenuItem(title: NSLocalizedString("No accounts configured", comment: ""),
                                     action: nil,
                                     keyEquivalent: "")
        placeholder.isEnabled = false
        menu.addItem(placeholder)

        menu.addItem(ClassicMenuItem(title: NSLocalizedString("Add an account…", comment: ""),
                                     handler: actions.openWindow))
    }

    // MARK: Account row

    private static func accountItem(for account: Account,
                                    fetcher: MessageFetcher?,
                                    isLocked: Bool = false,
                                    actions: Actions) -> NSMenuItem {
        // A locked account has no fetcher, so there is no unread count and no
        // submenu to build. The row exists to say why it's quiet and to offer
        // the way out.
        if isLocked {
            let item = ClassicMenuItem(title: lockedTitle(for: account)) {
                actions.subscribe()
            }
            item.image = providerIcon(for: account.type)
            item.toolTip = account.email
            return item
        }

        let hasAuthError = fetcher?.hasAuthError ?? false
        let unreadCount = fetcher?.unreadMessagesCount ?? 0
        let messages = fetcher?.messages ?? []

        if hasAuthError {
            let item = ClassicMenuItem(title: authErrorTitle(for: account)) {
                actions.reauthorize(account)
            }
            item.image = providerIcon(for: account.type)
            return item
        }

        let item = ClassicMenuItem(title: accountTitle(for: account, unreadCount: unreadCount)) {
            actions.openInbox(account)
        }
        item.image = providerIcon(for: account.type)
        item.toolTip = account.email

        if !messages.isEmpty {
            item.submenu = messagesSubmenu(for: account,
                                           messages: messages,
                                           unreadCount: unreadCount,
                                           actions: actions)
        }

        return item
    }

    private static func accountTitle(for account: Account, unreadCount: Int) -> String {
        unreadCount > 0 ? "\(account.displayName) (\(unreadCount))" : account.displayName
    }

    private static func lockedTitle(for account: Account) -> String {
        "\(account.displayName) (\(PaywallCopy.lockedBadge))"
    }

    private static func authErrorTitle(for account: Account) -> String {
        String(format: NSLocalizedString("%@ — Authorization expired", comment: ""), account.displayName)
    }

    // MARK: Messages submenu

    /// AppKit never sends an item's action when that item owns a submenu — the
    /// click opens the submenu instead. "Open Inbox" therefore leads the
    /// submenu, and an account with no unread mail keeps its direct click
    /// because it has no submenu at all.
    private static func messagesSubmenu(for account: Account,
                                        messages: [Message],
                                        unreadCount: Int,
                                        actions: Actions) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        submenu.addItem(ClassicMenuItem(title: NSLocalizedString("Open Inbox", comment: "")) {
            actions.openInbox(account)
        })
        submenu.addItem(.separator())

        for message in messages {
            let item = ClassicMenuItem(title: subjectLine(for: message)) {
                actions.openMessage(message)
            }
            item.toolTip = "\(message.sender) — \(Formatters.relativeLabel(for: message.serverDate))"
            submenu.addItem(item)
        }

        // The fetcher stores a bounded window of messages, so the server's
        // unread count can outrun the list. Say so rather than implying the
        // submenu is the whole inbox.
        let remaining = unreadCount - messages.count
        if remaining > 0 {
            submenu.addItem(.separator())
            let overflow = NSMenuItem(
                title: String(format: NSLocalizedString("%lld more unread", comment: ""), remaining),
                action: nil,
                keyEquivalent: ""
            )
            overflow.isEnabled = false
            submenu.addItem(overflow)
        }

        return submenu
    }

    private static func subjectLine(for message: Message) -> String {
        let subject = message.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = subject.isEmpty ? message.decodedSnippet : subject
        let collapsed = text.replacingOccurrences(of: "\n", with: " ")

        guard collapsed.count > maximumSubjectLength else {
            return collapsed.isEmpty ? NSLocalizedString("(No subject)", comment: "") : collapsed
        }
        return collapsed.prefix(maximumSubjectLength).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: Footer

    private static func footerItem(actions: Actions) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = ClassicMenuFooterView(actions: .init(checkAll: actions.checkAll,
                                                         openWindow: actions.openWindow,
                                                         openSettings: actions.openSettings,
                                                         quit: actions.quit))
        return item
    }

    private static func providerIcon(for type: AccountType) -> NSImage? {
        guard let image = NSImage(named: type.assetName)?.copy() as? NSImage else { return nil }
        image.size = providerIconSize
        return image
    }
}
