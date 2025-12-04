//
//  Sidebar.swift
//  Mail Notifier
//
//  Created by James Chen on 2021/06/15.
//  Copyright © 2021 ashchan.com. All rights reserved.
//

import SwiftUI

struct Sidebar: View {
    @AppStorage(Accounts.storageKey) var accounts = Accounts()
    @Binding var selection: String?

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach($accounts) { $account in
                        NavigationLink(
                            destination: AccountView(account: account),
                            tag: account.email,
                            selection: $selection
                        ) {
                            HStack(spacing: 10) {
                                AvatarView(
                                    image: account.type == .gmail ? "g.circle.fill" : "cloud.fill",
                                    backgroundColor: account.type == .gmail ? .red : .blue
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: account.email)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    Text(account.type == .gmail ? "Google" : "Outlook")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { source, destination in
                        let previousSelection = selection
                        accounts.reorder(fromOffsets: source, toOffset: destination)
                        DispatchQueue.main.async {
                            selection = previousSelection
                        }
                    }
                } header: {
                    Text("Accounts")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(nil)
                }

                Section {
                    NavigationLink(
                        destination: SettingsView(),
                        tag: "preferences",
                        selection: $selection
                    ) {
                        HStack(spacing: 10) {
                            AvatarView(image: "gearshape.fill", backgroundColor: .gray)
                            Text("Settings")
                                .font(.system(size: 13))
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Preferences")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 8) {
                Button(action: {
                    selection = "welcome"
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add Account")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Spacer()
            }
            .background(.regularMaterial)
        }
    }
}

struct AvatarView: View {
    var image: String
    var backgroundColor: Color

    var body: some View {
        Circle()
            .frame(width: 24, height: 24)
            .foregroundColor(backgroundColor)
            .overlay(
                Image(systemName: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundColor(.white)
            )
    }
}

struct Sidebar_Previews: PreviewProvider {
    static var previews: some View {
        Sidebar(
            accounts: [Account(email: "ashchan@gmail.com", type: .gmail)],
            selection: .constant("general")
        )
    }
}
