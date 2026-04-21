//
//  MainView.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct MainView: View {
    @AppStorage(Accounts.storageKey) var accounts = Accounts()
    @Binding var selection: String?
    @State private var isSettingsOpen = false

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                Sidebar(
                    accounts: accounts,
                    selection: $selection,
                    totalUnread: FetcherManager.shared.totalUnreadCount
                )
                .frame(width: 260)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.appBackground)

            SettingsDrawer(isPresented: $isSettingsOpen)
        }
        .frame(minWidth: 880, minHeight: 580)
        .background(WindowChrome())
        .onReceive(NotificationCenter.default.publisher(for: .accountAdded)) { notification in
            if let account = notification.object as? Account {
                selection = account.email
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsDrawer)) { _ in
            isSettingsOpen = true
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isSettingsOpen.toggle() }) {
                    Image(systemName: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
                .help("Settings (⌘,)")
            }
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
    func makeNSView(context: Context) -> NSView {
        let view = ChromeView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ChromeView)?.applyChrome()
    }
}

private final class ChromeView: NSView {
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
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor.black
        window.isMovableByWindowBackground = true
    }
}

#Preview {
    MainView(selection: .constant(nil))
        .frame(width: 1080, height: 720)
}
