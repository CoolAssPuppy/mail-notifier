//
//  AccountView.swift
//  Mail Notifr
//
//  Created by James Chen on 2021/06/16.
//  Copyright © 2021 ashchan.com. All rights reserved.
//

import SwiftUI

struct AccountView: View {
    @AppStorage(Accounts.storageKey) var accounts = Accounts()
    @State var account: Account
    @State private var showingDeleteAlert = false
    @State private var showingOAuthPrompt = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    notificationSection

                    Divider()
                        .padding(.vertical, 8)

                    behaviorSection

                    Divider()
                        .padding(.vertical, 8)

                    accountManagementSection

                    Spacer()
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.02),
                        Color.clear,
                        Color.green.opacity(0.01)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountUpdated)) {
            notification in
            if let updatedAccount = notification.object as? Account {
                if account.id == updatedAccount.id {
                    self.account = updatedAccount
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete Account")
                .alert(isPresented: $showingDeleteAlert) {
                    Alert(
                        title: Text("Delete this account from Mail Notifr?"),
                        message: Text("You can add your account again at any time."),
                        primaryButton: .default(Text("Delete")) {
                            self.delete()
                        },
                        secondaryButton: .cancel()
                    )
                }
                Button {
                    reauthorize()
                } label: {
                    Image(systemName: "key.icloud")
                }
                .buttonStyle(.borderless)
                .help("Reauthorize Account")
            }
        }
       .sheet(isPresented: $showingOAuthPrompt) {
            OAuthPrompt()
                .onAppear {
                    OAuthPrompt.accountType = account.type
                }
        }
        .onChange(of: account) { newValue in
           update(account: account)
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.email)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(account.type == .gmail ? "Google Account" : "Outlook Account")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial)
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "bell.fill", title: "Notifications", gradient: [.orange, .red])

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $account.notificationEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable notifications")
                            .font(.body)
                        Text("Show system notifications for new mail")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notification sound")
                        .font(.body)

                    Picker("", selection: $account.notificationSound) {
                       Text(verbatim: "None")
                            .tag("")
                        Divider()
                        ForEach(Sound.allCases) { sound in
                            Text(sound.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: account.notificationSound) { newValue in
                        if let sound = Sound(rawValue: newValue) {
                            sound.nsSound?.play()
                        }
                    }

                    Text("Play this sound when new mail arrives")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "slider.horizontal.3", title: "Behavior", gradient: [.blue, .purple])

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open emails with")
                        .font(.body)

                    Picker("", selection: $account.openInBrowser) {
                       Text(verbatim: "Default Browser")
                            .tag("")
                        Divider()
                        ForEach(Browser.all) { browser in
                            Text(browser.name)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Which browser to use when opening mail links")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Check for new mail every")
                            .font(.body)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("", value: $account.checkInterval, formatter: NumberFormatter())
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                            Text("min")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("How often to check for new messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }

    private var accountManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "person.circle.fill", title: "Account Management", gradient: [.green, .mint])

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $account.enabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable this account")
                            .font(.body)
                        Text("When disabled, this account will not check for new mail")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reauthorize account")
                            .font(.body)
                        Text("Sign in again to refresh your authentication")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        reauthorize()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "key.icloud")
                            Text("Reauthorize")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }

    private func sectionHeader(icon: String, title: String, gradient: [Color]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

private extension AccountView {
    func update(account: Account) {
        accounts.update(account: account)
    }

    func delete() {
        accounts.delete(account: account)
    }

    func reauthorize() {
        OAuthPrompt.accountType = account.type
        showingOAuthPrompt = true
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView(account: Account(email: "ashchan@gmail.com", type: .gmail))
    }
}
