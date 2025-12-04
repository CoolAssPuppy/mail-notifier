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

    var body: some View {
        NavigationView {
            Sidebar(accounts: accounts, selection: $selection)
                .toolbar {
                    Button(action: toggleSidebar) {
                        Image(systemName: "sidebar.left")
                            .help("Toggle Sidebar")
                    }
                }
                .frame(minWidth: 220, alignment: .leading)

            WelcomeView()
        }
       .frame(minWidth: 600, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
       .onReceive(NotificationCenter.default.publisher(for: .accountAdded)) {
           notification in
           if let newAccount = notification.object as? Account {
               selection = newAccount.email
           }
       }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

#Preview {
    MainView(selection: .constant(""))
}
