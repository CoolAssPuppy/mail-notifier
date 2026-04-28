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
    private var rightClickMenu: NSMenu?
    private var popover: NSPopover?
    private var popoverEventMonitor: Any?
    private lazy var popoverModel = MenuBarPopoverModel()
    private var subscriptions = Set<AnyCancellable>()
    let fetcherManager = FetcherManager.shared
    private let notificationService = NotificationService()
    private let updaterManager = UpdaterManager.shared
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        verifyURLSchemesRegistered()

        Telemetry.setup()

        notificationService.delegate = self
        FriendlyNameStore.shared.start()
        registerShortcuts()
        subscribeToNotifications()
        setupStatusItem()
        fetcherManager.update()
        updateMenuBar()
        notificationService.setup()
        setupURLHandler()

        Telemetry.capture("app.launched")
        reportUpdateInstalledIfNeeded()

        if !Accounts.hasAccounts || AppSettings.shared.openSettingsOnStart {
            showPreferences()
        }
    }

    /// Sanity-check that the OAuth redirect schemes computed at runtime from
    /// `Secrets.xcconfig` match what's registered in `Info.plist`. If they
    /// drift, the OAuth dance silently fails after the redirect — the user
    /// is bounced through Google/Microsoft, returns to the system, and
    /// nothing happens. Logging at startup makes the misconfiguration loud.
    private func verifyURLSchemesRegistered() {
        let registered: Set<String> = {
            guard let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else { return [] }
            let schemes = types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
            return Set(schemes.map { $0.lowercased() })
        }()

        let expected: [(name: String, scheme: String)] = [
            ("Google", GoogleOAuthClient.redirectScheme),
            ("Outlook", OutlookOAuthClient.redirectScheme)
        ]

        for entry in expected where !entry.scheme.isEmpty {
            if !registered.contains(entry.scheme.lowercased()) {
                Log.app.error("\(entry.name, privacy: .public) OAuth redirect scheme \(entry.scheme, privacy: .public) is not registered in Info.plist CFBundleURLTypes — sign-in callbacks will be dropped")
            }
        }
    }

    /// Fires `update.installed` when the short-version changes between
    /// launches. Silent on first ever launch. See Linear Bar's equivalent
    /// for rationale.
    private func reportUpdateInstalledIfNeeded() {
        let key = "com.strategicnerds.MailNotifier.telemetry.lastLaunchedVersion"
        let defaults = UserDefaults.standard
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let previous = defaults.string(forKey: key)
        defaults.set(current, forKey: key)
        guard let previous, !previous.isEmpty, previous != current else { return }
        Telemetry.capture("update.installed", properties: ["from": previous, "to": current])
    }
}

// MARK: - Setup

private extension AppDelegate {
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }
        button.image = NSImage(named: "NoMailsTemplate")
        button.imagePosition = .imageLeft
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        rightClickMenu = createRightClickMenu()
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
    private static let maximumIncomingURLLength = 8_192
    private static let maximumMailToFieldLength = 2_048

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            Log.app.error("handleGetURLEvent: Failed to get URL from event")
            return
        }

        guard urlString.count <= Self.maximumIncomingURLLength else {
            Log.app.warning("handleGetURLEvent: Ignored incoming URL that exceeded max length")
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
                guard let self,
                      let email = notification.object as? String else { return }
                self.updateMenuBar()
                notificationService.handleMessagesFetched(email: email, fetcherManager: fetcherManager)
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .mailToReceived)
            .sink { [weak self] notification in
                guard let url = notification.object as? URL else { return }
                self?.handleMailTo(url)
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .openPreferencesWindow)
            .sink { [weak self] _ in
                self?.showPreferences()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: .friendlyNamesChanged)
            .sink { [weak self] _ in
                self?.updateMenuBar()
            }
            .store(in: &subscriptions)
    }
}

// MARK: - Menu Bar Updates

private extension AppDelegate {
    func updateMenuBar() {
        popoverModel.refresh()
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

// MARK: - Status Item Click Handling

extension AppDelegate {
    @objc func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)

        if isRightClick {
            showRightClickMenu()
        } else {
            togglePopover()
        }
    }

    private func showRightClickMenu() {
        guard let statusItem, let menu = rightClickMenu else { return }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Detach so the next left-click still triggers our action.
        DispatchQueue.main.async { [weak statusItem] in
            statusItem?.menu = nil
        }
    }
}

// MARK: - Popover

extension AppDelegate: NSPopoverDelegate {
    private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let popover = self.popover ?? buildPopover()
        self.popover = popover

        popoverModel.refresh()

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        Telemetry.capture("menu.opened")

        // Dismiss when the user clicks outside the popover.
        popoverEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.popover?.performClose(nil)
        }
    }

    private func buildPopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let actions = MenuBarPopoverActions(
            openMessage: { [weak self] message in
                self?.popover?.performClose(nil)
                self?.openMessage(messageId: message.id, email: message.email)
            },
            openInbox: { [weak self] account in
                self?.popover?.performClose(nil)
                self?.openURL(url: account.baseURL, in: account.browser)
            },
            reauthorize: { [weak self] account in
                self?.popover?.performClose(nil)
                self?.showPreferences()
                Accounts.authorize(type: account.type)
            },
            checkAll: { [weak self] in
                self?.checkAllMails()
            },
            openWindow: { [weak self] in
                self?.popover?.performClose(nil)
                self?.showPreferences()
            },
            openSettings: { [weak self] in
                self?.popover?.performClose(nil)
                self?.showSettingsDrawer()
            },
            quit: {
                NSApp.terminate(nil)
            }
        )

        let view = MenuBarPopover(model: popoverModel, actions: actions)
        popover.contentViewController = NSHostingController(rootView: view)
        return popover
    }

    func popoverDidClose(_ notification: Notification) {
        if let monitor = popoverEventMonitor {
            NSEvent.removeMonitor(monitor)
            popoverEventMonitor = nil
        }
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

    @objc func checkForUpdates() {
        Task { @MainActor in
            UpdaterManager.shared.checkForUpdates()
        }
    }

    @objc func composeMail() {
        composeMail(to: nil, subject: nil)
    }

    func composeMail(to: String? = nil, subject: String? = nil) {
        let account = Accounts.default.first
        var components = URLComponents(url: account?.baseURL ?? URL(string: "https://mail.google.com")!, resolvingAgainstBaseURL: false)

        var queryItems: [URLQueryItem] = []
        if account?.type == .outlook {
            queryItems.append(URLQueryItem(name: "path", value: "/mail/action/compose"))
        } else {
            queryItems += [
                URLQueryItem(name: "view", value: "cm"),
                URLQueryItem(name: "tf", value: "0"),
                URLQueryItem(name: "fs", value: "1")
            ]
        }

        if let to, !to.isEmpty {
            queryItems.append(URLQueryItem(name: "to", value: to))
        }

        if let subject, !subject.isEmpty {
            let parameterName = account?.type == .outlook ? "subject" : "su"
            queryItems.append(URLQueryItem(name: parameterName, value: subject))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else { return }
        openURL(url: url, in: account?.browser)
    }

    @objc func openInbox(_ sender: Any) {
        guard let account = account(from: email(from: sender)) else { return }
        openURL(url: account.baseURL, in: account.browser)
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

    /// Synchronous so callers (e.g. `reauthorize`) can rely on the window
    /// being key by the time this returns — `Accounts.authorize` reads
    /// `NSApp.keyWindow` to decide whether to use ASWebAuthenticationSession
    /// or fall back to the deprecated browser flow.
    @objc func showPreferences() {
        // Stay .accessory — we never want a dock icon, even while the main
        // window is open. .accessory apps can still own standard windows;
        // makeKeyAndOrderFront + activate is enough to focus them.
        NSApp.activate(ignoringOtherApps: true)

        if let existingWindow = preferencesWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: MainViewWrapper())
        window.title = "Mail Notifier"
        window.toolbar = nil
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor.black
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.delegate = self

        preferencesWindow = window
    }

    @objc func showSettingsDrawer() {
        showPreferences()
        Task { @MainActor in
            // Wait one runloop tick so the window exists and MainView is mounted.
            try? await Task.sleep(nanoseconds: 50_000_000)
            NotificationCenter.default.post(name: .openSettingsDrawer, object: nil)
        }
    }
}

// MARK: - Mail To Handling

extension AppDelegate {
    func handleMailTo(_ url: URL) {
        guard url.scheme == "mailto" else { return }

        let rawRecipient = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
        let fallbackRecipient = rawRecipient.components(separatedBy: "?").first ?? ""
        let recipient = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .percentEncodedPath.removingPercentEncoding
            ?? fallbackRecipient.removingPercentEncoding
            ?? ""

        let subject = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == "subject" })?
            .value

        let validatedRecipient = sanitizeMailToField(recipient)
        let validatedSubject = sanitizeMailToField(subject)
        composeMail(to: validatedRecipient, subject: validatedSubject)
    }

    private func sanitizeMailToField(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= Self.maximumMailToFieldLength else {
            Log.app.warning("Ignored mailto field exceeding max length")
            return nil
        }
        let disallowed = CharacterSet.newlines.union(.controlCharacters)
        guard trimmed.rangeOfCharacter(from: disallowed) == nil else {
            Log.app.warning("Ignored mailto field containing control/newline characters")
            return nil
        }
        return trimmed
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == preferencesWindow else { return }
        preferencesWindow = nil
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
