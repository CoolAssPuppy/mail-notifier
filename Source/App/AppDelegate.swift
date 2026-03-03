//
//  AppDelegate.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit
import Combine
import SwiftUI
import KeyboardShortcuts

// MARK: - Keyboard Shortcuts

extension KeyboardShortcuts.Name {
    static let checkAllMails = Self("checkAllMails")
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var subscriptions = Set<AnyCancellable>()
    private let fetcherManager = FetcherManager.shared
    private let notificationService = NotificationService()
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        notificationService.delegate = self
        registerShortcuts()
        subscribeToNotifications()
        setupStatusItem()
        fetcherManager.update()
        updateMenuBar()
        notificationService.setup()
        setupURLHandler()

        if !Accounts.hasAccounts || AppSettings.shared.openSettingsOnStart {
            showPreferences()
        }
    }
}

// MARK: - Setup

private extension AppDelegate {
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }
        button.image = NSImage(named: "NoMailsTemplate")
        button.imagePosition = .imageLeft

        menu = createMenu()
        statusItem?.menu = menu
    }

    func setupURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func registerShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .checkAllMails) { [weak self] in
            self?.checkAllMails()
        }
    }
}

// MARK: - URL Handling

extension AppDelegate {
    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            Log.app.error("handleGetURLEvent: Failed to get URL from event")
            return
        }

        URLRouter.route(url: url)
    }
}

// MARK: - Notification Subscriptions

private extension AppDelegate {
    func subscribeToNotifications() {
        NotificationCenter.default
            .publisher(for: .accountAdded)
            .sink { [weak self] notification in
                self?.fetcherManager.update(fetchingAccount: notification.object as? Account)
                self?.updateMenuBar()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .accountDeleted)
            .sink { [weak self] _ in
                self?.fetcherManager.rebuild()
                self?.updateMenuBar()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .accountUpdated)
            .sink { [weak self] notification in
                guard let self,
                      let account = notification.object as? Account else { return }

                let needsRescheduling = notification.userInfo?["needsRescheduling"] as? Bool ?? false
                let needsImmediateFetching = notification.userInfo?["needsImmediateFetching"] as? Bool ?? false

                if needsRescheduling {
                    fetcherManager.rebuild()
                    fetcherManager.fetcher(for: account.email)?.reschedule()
                } else if needsImmediateFetching {
                    fetcherManager.update(fetchingAccount: account)
                } else {
                    fetcherManager.rebuild()
                }
                updateMenuBar()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .accountsReordered)
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .showUnreadCountSettingChanged)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .unreadCountUpdated)
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .messagesFetched)
            .sink { [weak self] notification in
                guard let self else { return }
                let email = notification.object as? String ?? ""
                if let menu { updateMenu(menu) }
                notificationService.handleMessagesFetched(email: email, fetcherManager: fetcherManager)
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .mailToReceived)
            .sink { [weak self] notification in
                let param = notification.object as? String ?? ""
                self?.handleMailTo(param)
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .openPreferencesWindow)
            .sink { [weak self] _ in
                self?.showPreferences()
            }
            .store(in: &subscriptions)
    }
}

// MARK: - Menu Bar Updates

private extension AppDelegate {
    func updateMenuBar() {
        guard let menu else { return }
        updateMenu(menu)
        updateStatusItem()
    }

    func updateStatusItem() {
        guard let button = statusItem?.button else { return }

        let messagesCount = fetcherManager.totalUnreadCount

        button.title = (messagesCount > 0 && AppSettings.shared.showUnreadCount) ? "\(messagesCount)" : ""

        if messagesCount > 0 {
            let format = messagesCount == 1
                ? NSLocalizedString("Unread Message", comment: "")
                : NSLocalizedString("Unread Messages", comment: "")
            button.toolTip = String(format: format, messagesCount)
            button.image = NSImage(named: "HaveMailsTemplate")
        } else {
            button.toolTip = ""
            button.image = NSImage(named: "NoMailsTemplate")
        }

        button.appearsDisabled = Accounts.default.enabled.isEmpty
    }
}

// MARK: - Commands

extension AppDelegate {
    private func email(from sender: Any) -> String? {
        (sender as? NSMenuItem)?.representedObject as? String
    }

    private func account(from email: String?) -> Account? {
        guard let email else { return nil }
        return Accounts.default.find(email: email)
    }

    func fetcher(for email: String?) -> MessageFetcher? {
        fetcherManager.fetcher(for: email)
    }

    private func openMessage(messageId: String, email: String) {
        guard let account = account(from: email) else { return }
        openURL(url: Message.url(type: account.type, email: email, id: messageId), in: account.browser)
    }

    func openURL(url: URL, in browser: Browser?) {
        if let browser, !browser.isDefault,
           let browserUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.identifier) {
            NSWorkspace.shared.open([url], withApplicationAt: browserUrl, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func checkAllMails() {
        fetcherManager.checkAll()
    }

    @objc func composeMail() {
        composeMail(to: nil, subject: nil)
    }

    func composeMail(to: String? = nil, subject: String? = nil) {
        let account = Accounts.default.first
        let baseURL = account?.baseUrl ?? "https://mail.google.com/"

        var urlString: String
        if account?.type == .outlook {
            urlString = baseURL + "?path=/mail/action/compose"
        } else {
            urlString = baseURL + "?view=cm&tf=0&fs=1"
        }

        if let to, !to.isEmpty {
            urlString += "&to=\(to)"
        }

        if let subject, !subject.isEmpty {
            let param = account?.type == .outlook ? "subject" : "su"
            urlString += "&\(param)=\(subject)"
        }

        guard let url = URL(string: urlString) else { return }
        openURL(url: url, in: account?.browser)
    }

    @objc func openInbox(_ sender: Any) {
        guard let account = account(from: email(from: sender)),
              let url = URL(string: account.baseUrl) else { return }
        openURL(url: url, in: account.browser)
    }

    @objc func checkMails(_ sender: Any) {
        guard let account = account(from: email(from: sender)) else { return }
        fetcher(for: account.email)?.fetch()
    }

    @objc func openMessage(_ sender: Any) {
        guard let menuItem = sender as? NSMenuItem,
              let message = menuItem.representedObject as? Message else { return }
        openMessage(messageId: message.id, email: message.email)
    }

    @objc func toggleAccount(_ sender: Any) {
        guard var account = account(from: email(from: sender)) else { return }
        account.enabled.toggle()
        Accounts.default.update(account: account)
    }

    @objc func reauthorize(_ sender: Any) {
        showPreferences()
        guard let account = (sender as? NSMenuItem)?.representedObject as? Account else { return }
        Accounts.authorize(type: account.type)
    }

    @objc func showPreferences() {
        NSApp.setActivationPolicy(.regular)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))

            NSApp.activate(ignoringOtherApps: true)

            if let existingWindow = preferencesWindow {
                existingWindow.makeKeyAndOrderFront(nil)
                return
            }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentView = NSHostingView(rootView: MainViewWrapper())
            window.title = "Mail Notifier"
            window.toolbar = nil
            window.isReleasedWhenClosed = false
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.delegate = self

            preferencesWindow = window
        }
    }
}

// MARK: - Mail To Handling

extension AppDelegate {
    func handleMailTo(_ param: String) {
        let components = param.split(separator: "?")
        guard let to = components.first else { return }

        var subject: String?
        if components.count > 1 {
            let query = components[1].split(separator: "&").first { $0.hasPrefix("subject=") }
            subject = query?.replacingOccurrences(of: "subject=", with: "")
        }

        composeMail(to: String(to), subject: subject)
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == preferencesWindow else { return }
        preferencesWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - NotificationServiceDelegate

extension AppDelegate: NotificationServiceDelegate {
    func notificationService(_ service: NotificationService, didRequestOpenMessage messageId: String, email: String) {
        openMessage(messageId: messageId, email: email)
    }
}

// MARK: - MainViewWrapper

private struct MainViewWrapper: View {
    @State private var selection: String?

    var body: some View {
        MainView(selection: $selection)
    }
}
