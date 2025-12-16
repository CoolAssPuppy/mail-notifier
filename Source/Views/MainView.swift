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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(accounts: accounts, selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 280)
        } detail: {
            if let selection {
                detailView(for: selection)
            } else {
                WelcomeView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(.hidden, for: .windowToolbar)
        .toolbar(removing: .sidebarToggle)
        .onChange(of: columnVisibility) { _, newValue in
            // Force sidebar to always be visible
            if newValue != .all {
                columnVisibility = .all
            }
        }
        .background(WindowAccessor())
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .accountAdded)) {
            notification in
            if let newAccount = notification.object as? Account {
                selection = newAccount.email
            }
        }
    }

    @ViewBuilder
    private func detailView(for selection: String) -> some View {
        if selection == "preferences" {
            SettingsView()
        } else if selection == "welcome" {
            WelcomeView()
        } else if let account = accounts.first(where: { $0.email == selection }) {
            AccountView(account: account)
        } else {
            WelcomeView()
        }
    }
}

// MARK: - Window Accessor

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> ToolbarRemovingView {
        ToolbarRemovingView()
    }

    func updateNSView(_ nsView: ToolbarRemovingView, context: Context) {
        nsView.removeToolbar()
    }
}

private class ToolbarRemovingView: NSView {
    private var observation: NSKeyValueObservation?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupObservation()
        removeToolbar()
    }

    private func setupObservation() {
        observation?.invalidate()
        guard let window = window else { return }

        // Observe toolbar changes and remove immediately
        observation = window.observe(\.toolbar, options: [.new]) { [weak self] window, _ in
            DispatchQueue.main.async {
                self?.removeToolbar()
            }
        }
    }

    func removeToolbar() {
        window?.toolbar = nil
    }

    deinit {
        observation?.invalidate()
    }
}

#Preview {
    MainView(selection: .constant(""))
}
