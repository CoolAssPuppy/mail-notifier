//
//  MainView.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI
import AppKit

struct MainView: View {
    @AppStorage(Accounts.storageKey) var accounts = Accounts()
    @ObservedObject private var themeStore = ThemeStore.shared
    #if !MAC_APP_STORE
    @ObservedObject private var entitlement = EntitlementManager.shared
    @State private var paywallTrigger: PaywallTrigger?
    #endif
    @ObservedObject private var demoMode = DemoMode.shared
    @Binding var selection: String?
    @State private var isSettingsOpen = false
    #if MAC_APP_STORE
    @State private var isTipJarOpen = false
    #endif
    @State private var signinFailure: SigninFailure?

    var body: some View {
        let theme = themeStore.palette
        let view = ZStack(alignment: .top) {
            HStack(spacing: 0) {
                Sidebar(
                    accounts: accounts,
                    selection: $selection,
                    totalUnread: FetcherManager.shared.totalUnreadCount,
                    lockedEmails: lockedEmails,
                    onOpenSettings: { isSettingsOpen.toggle() },
                    onOpenTipJar: openTipJar
                )
                .frame(width: 260)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(theme.background)

            SettingsDrawer(isPresented: $isSettingsOpen)
        }
        .frame(minWidth: 880, minHeight: 580)
        .background(WindowChrome(palette: theme))
        .environment(\.theme, theme)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .onReceive(NotificationCenter.default.publisher(for: .accountAdded)) { notification in
            if let account = notification.object as? Account {
                selection = account.email
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsDrawer)) { _ in
            isSettingsOpen = true
        }
        // Every sign-in starts from this window (the menus open it first), so
        // a failed one is explained here, with a way to try again.
        .onReceive(NotificationCenter.default.publisher(for: .signinFailed)) { notification in
            signinFailure = notification.object as? SigninFailure
        }
        .alert(SigninFailure.title,
               isPresented: Binding(get: { signinFailure != nil },
                                    set: { if !$0 { signinFailure = nil } }),
               presenting: signinFailure) { failure in
            Button("Retry") { Accounts.authorize(type: failure.provider) }
            if failure.kind == .adminConsentRequired {
                Button("Copy link for IT") { copyAdminConsentLink() }
            }
            Button("Cancel", role: .cancel) { }
        } message: { failure in
            Text(failure.message)
        }
        #if MAC_APP_STORE
        return view
            .onReceive(NotificationCenter.default.publisher(for: .openTipJar)) { _ in openTipJar() }
            .sheet(isPresented: $isTipJarOpen) {
                VStack(alignment: .trailing, spacing: 12) {
                    TipCard()
                    Button("Done") { isTipJarOpen = false }
                        .keyboardShortcut(.cancelAction)
                }
                .padding(20)
                .frame(width: 400)
                .background(theme.background)
                .environment(\.theme, theme)
                .environment(\.colorScheme, theme.isDark ? .dark : .light)
            }
        #else
        return view
            .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { notification in
                paywallTrigger = notification.object as? PaywallTrigger ?? .addAccount
            }
            .sheet(item: $paywallTrigger) { trigger in
                PaywallSheet(trigger: trigger) { paywallTrigger = nil }
                    .environment(\.theme, themeStore.palette)
                    .environment(\.colorScheme, themeStore.palette.isDark ? .dark : .light)
            }
        #endif
    }

    private func openTipJar() {
        #if MAC_APP_STORE
        isTipJarOpen = true
        #endif
    }

    private func copyAdminConsentLink() {
        let url = SigninFailure.adminConsentURL(clientID: OutlookOAuthClient.clientID)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    /// Enabled accounts the subscription is currently holding back. Computed
    /// here and passed down so the sidebar and the account view agree, and so
    /// both redraw when `entitlement.record` changes.
    private var lockedEmails: Set<String> {
        #if MAC_APP_STORE
        []
        #else
        Set(Accounts.partition(enabled: Array(accounts.enabled),
                               isEntitled: entitlement.isEntitled || demoMode.isOn).locked.map(\.email))
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if accounts.isEmpty || selection == "welcome" {
            WelcomeView()
        } else if let email = selection,
                  let account = accounts.first(where: { $0.email == email }) {
            AccountView(account: account, isLocked: lockedEmails.contains(account.email))
                .id(account.email)
        } else if let firstAccount = accounts.first {
            AccountView(account: firstAccount, isLocked: lockedEmails.contains(firstAccount.email))
                .id(firstAccount.email)
                .onAppear {
                    selection = firstAccount.email
                }
        } else {
            WelcomeView()
        }
    }
}

// MARK: - Window chrome configuration

private struct WindowChrome: NSViewRepresentable {
    let palette: ThemePalette

    func makeNSView(context: Context) -> ChromeView {
        ChromeView(palette: palette)
    }

    func updateNSView(_ nsView: ChromeView, context: Context) {
        nsView.palette = palette
        nsView.applyChrome()
    }
}

private final class ChromeView: NSView {
    var palette: ThemePalette

    init(palette: ThemePalette) {
        self.palette = palette
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyChrome()
    }

    func applyChrome() {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = nil
        window.appearance = palette.nsAppearance
        window.backgroundColor = palette.nsBackground
        window.isMovableByWindowBackground = true
    }
}

#Preview {
    MainView(selection: .constant(nil))
        .frame(width: 1080, height: 720)
}
