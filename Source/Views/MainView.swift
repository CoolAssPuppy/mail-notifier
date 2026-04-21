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
    @Binding var selection: String?
    @State private var isSettingsOpen = false

    var body: some View {
        let theme = themeStore.palette
        return ZStack(alignment: .top) {
            HStack(spacing: 0) {
                Sidebar(
                    accounts: accounts,
                    selection: $selection,
                    totalUnread: FetcherManager.shared.totalUnreadCount,
                    onOpenSettings: { isSettingsOpen.toggle() }
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
    }

    @ViewBuilder
    private var content: some View {
        if accounts.isEmpty || selection == "welcome" {
            WelcomeView()
        } else if let email = selection,
                  let account = accounts.first(where: { $0.email == email }) {
            AccountView(account: account)
                .id(account.email)
        } else if let firstAccount = accounts.first {
            AccountView(account: firstAccount)
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
