//
//  AccountView.swift
//  Mail Notifier
//
//  Detail pane for a configured account. Lets the user edit friendly name,
//  notification + polling behavior, and reauthorize or remove the account.
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct AccountView: View {
    @AppStorage(Accounts.storageKey) var accounts = Accounts()
    @State var account: Account
    @State private var friendlyNameDraft: String
    @State private var showingDeleteAlert = false

    init(account: Account) {
        self._account = State(initialValue: account)
        self._friendlyNameDraft = State(initialValue: account.friendlyName ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    identityCard

                    notificationsCard

                    behaviorCard

                    managementCard

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .onReceive(NotificationCenter.default.publisher(for: .accountUpdated)) { notification in
            guard let updated = notification.object as? Account,
                  updated.id == account.id else { return }
            account = updated
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendlyNamesChanged)) { notification in
            if let email = notification.object as? String, email != account.email { return }
            friendlyNameDraft = account.friendlyName ?? ""
        }
        .onChange(of: account) { _, newValue in
            accounts.update(account: newValue)
        }
        .alert("Remove account?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                accounts.delete(account: account)
            }
        } message: {
            Text("This removes \(account.displayName) from Mail Notifier along with all stored tokens.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ProviderBadge(type: account.type, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.appForeground)

                headerMeta
            }

            Spacer(minLength: 12)

            headerActions
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .overlay(
            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var headerMeta: some View {
        HStack(spacing: 10) {
            Text(providerLabel)
                .font(.system(size: 11))
                .foregroundStyle(Color.appMuted)

            dot

            statusBadge

            if let lastChecked, let lastText = lastCheckedText(lastChecked) {
                dot
                Text(lastText)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted)
                    .monospacedDigit()
            }
        }
    }

    private var providerLabel: String {
        account.type == .gmail ? "Gmail" : "Outlook"
    }

    private var dot: some View {
        Circle()
            .fill(Color.appDim)
            .frame(width: 3, height: 3)
    }

    @ViewBuilder
    private var statusBadge: some View {
        let fetcher = FetcherManager.shared.fetcher(for: account.email)
        if !account.enabled {
            statusLabel(color: .appMuted, label: "Disabled")
        } else if fetcher?.hasAuthError == true {
            statusLabel(color: .appDestructive, label: "Auth expired")
        } else {
            statusLabel(color: .appSuccess, label: "Active")
        }
    }

    private func statusLabel(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.5), radius: 4)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private var lastChecked: Date? {
        FetcherManager.shared.fetcher(for: account.email)?.lastCheckedAt
    }

    private func lastCheckedText(_ date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let unread = FetcherManager.shared.fetcher(for: account.email)?.unreadMessagesCount ?? 0
        return "Checked \(formatter.string(from: date)) · \(unread) unread"
    }

    private var headerActions: some View {
        HStack(spacing: 6) {
            AppSecondaryButton(title: "Check now", systemImage: "arrow.triangle.2.circlepath") {
                FetcherManager.shared.fetcher(for: account.email)?.fetch()
            }
            AppIconButton(systemName: "arrow.up.forward.app", help: "Open inbox in browser") {
                NSWorkspace.shared.open(account.baseURL)
            }
        }
    }

    // MARK: - Identity card

    private var identityCard: some View {
        AppCard("Identity") {
            VStack(spacing: 0) {
                AppSettingRow(
                    "Friendly name",
                    description: "Shown in place of the email everywhere (menu bar, sidebar, notifications). Syncs across your Macs."
                ) {
                    TextField("e.g. Work, Supabase, Personal", text: $friendlyNameDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .fill(Color.appCardInset)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .strokeBorder(Color.appBorderStrong, lineWidth: 1)
                        )
                        .frame(width: 240)
                        .onSubmit(commitFriendlyName)
                        .onChange(of: friendlyNameDraft) { _, newValue in
                            // Debounce-less commit on every edit is fine — writes are local.
                            FriendlyNameStore.setName(newValue, for: account.email)
                        }
                }

                AppRowDivider().padding(.vertical, 12)

                AppSettingRow("Email address") {
                    Text(account.email)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.appMuted)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func commitFriendlyName() {
        FriendlyNameStore.setName(friendlyNameDraft, for: account.email)
    }

    // MARK: - Notifications card

    private var notificationsCard: some View {
        AppCard("Notifications") {
            VStack(spacing: 0) {
                AppSettingRow(
                    "Enable notifications",
                    description: "Show system notifications when new mail arrives in this account."
                ) {
                    Toggle("", isOn: $account.notificationEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Color.appPrimary)
                }

                AppRowDivider().padding(.vertical, 12)

                AppSettingRow(
                    "Notification sound",
                    description: "Plays when new mail arrives. VIP senders can override this."
                ) {
                    HStack(spacing: 8) {
                        AppIconButton(systemName: "speaker.wave.2.fill", help: "Preview") {
                            account.sound?.nsSound?.play()
                        }

                        Picker("", selection: $account.notificationSound) {
                            Text("None").tag("")
                            Divider()
                            ForEach(Sound.allCases) { sound in
                                Text(sound.name).tag(sound.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 160)
                        .onChange(of: account.notificationSound) { _, newValue in
                            Sound(rawValue: newValue)?.nsSound?.play()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Behavior card

    private var behaviorCard: some View {
        AppCard("Behavior") {
            VStack(spacing: 0) {
                AppSettingRow(
                    "Open emails with",
                    description: "Which browser to use when you click a message."
                ) {
                    Picker("", selection: $account.openInBrowser) {
                        Text("Default Browser").tag("")
                        Divider()
                        ForEach(Browser.all) { browser in
                            Text(browser.name).tag(browser.identifier)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 200)
                }

                AppRowDivider().padding(.vertical, 12)

                AppSettingRow(
                    "Check for new mail every",
                    description: "Polling interval in minutes (1 – 900)."
                ) {
                    HStack(spacing: 6) {
                        Button(action: { account.checkInterval = max(1, account.checkInterval - 1) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.appMuted)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(account.checkInterval)) min")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appForeground)
                            .monospacedDigit()
                            .frame(minWidth: 52)
                            .padding(.vertical, 4)
                            .background(Color.appCardInset)
                            .overlay(
                                Rectangle().fill(Color.appBorderStrong).frame(width: 1),
                                alignment: .leading
                            )
                            .overlay(
                                Rectangle().fill(Color.appBorderStrong).frame(width: 1),
                                alignment: .trailing
                            )

                        Button(action: { account.checkInterval = min(900, account.checkInterval + 1) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.appMuted)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(Color.appCardInset)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .strokeBorder(Color.appBorderStrong, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Management card

    private var managementCard: some View {
        AppCard("Account Management") {
            VStack(spacing: 0) {
                AppSettingRow(
                    "Enable this account",
                    description: "When off, this inbox is skipped during checks."
                ) {
                    Toggle("", isOn: $account.enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Color.appPrimary)
                }

                AppRowDivider().padding(.vertical, 12)

                AppSettingRow(
                    "Reauthorize",
                    description: "Sign in again to refresh OAuth tokens."
                ) {
                    AppSecondaryButton(title: "Reauthorize", systemImage: "key.icloud") {
                        Accounts.authorize(type: account.type)
                    }
                }

                AppRowDivider().padding(.vertical, 12)

                AppSettingRow(
                    "Remove account",
                    description: "Deletes the account and all stored tokens. This is permanent."
                ) {
                    AppSecondaryButton(title: "Remove", systemImage: "trash", tint: .appDestructive) {
                        showingDeleteAlert = true
                    }
                }
            }
        }
    }
}

#Preview {
    AccountView(account: Account(email: "user@example.com", type: .gmail))
        .frame(width: 820, height: 560)
}
