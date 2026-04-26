//
//  AccountView.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct AccountView: View {
    @AppStorage(Accounts.storageKey) var accounts = Accounts()
    @ObservedObject private var friendlyNames = FriendlyNameStore.shared
    @Environment(\.theme) private var theme
    @State var account: Account
    @State private var friendlyNameDraft: String
    @State private var showingDeleteAlert = false
    @FocusState private var friendlyFieldFocused: Bool

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
        .background(theme.background)
        .onReceive(NotificationCenter.default.publisher(for: .accountUpdated)) { notification in
            guard let updated = notification.object as? Account,
                  updated.id == account.id else { return }
            account = updated
        }
        .onChange(of: friendlyNames.names) { _, _ in
            if !friendlyFieldFocused {
                friendlyNameDraft = account.friendlyName ?? ""
            }
        }
        .onChange(of: friendlyFieldFocused) { _, focused in
            if !focused {
                FriendlyNameStore.shared.setName(friendlyNameDraft, for: account.email)
            }
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
                    .foregroundStyle(theme.foreground)

                headerMeta
            }

            Spacer(minLength: 12)

            headerActions
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .overlay(
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var fetcher: MessageFetcher? {
        FetcherManager.shared.fetcher(for: account.email)
    }

    @ViewBuilder
    private var headerMeta: some View {
        let fetcher = self.fetcher
        HStack(spacing: 10) {
            Text(account.type.displayLabel)
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)

            dot

            statusBadge(fetcher: fetcher)

            if let timestamp = fetcher?.lastCheckedAt {
                dot
                Text("Checked \(Formatters.shortTime.string(from: timestamp)) · \(fetcher?.unreadMessagesCount ?? 0) unread")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.muted)
                    .monospacedDigit()
            }
        }
    }

    private var dot: some View {
        Circle()
            .fill(theme.dim)
            .frame(width: 3, height: 3)
    }

    @ViewBuilder
    private func statusBadge(fetcher: MessageFetcher?) -> some View {
        if !account.enabled {
            statusLabel(color: theme.muted, label: "Disabled")
        } else if fetcher?.hasAuthError == true {
            statusLabel(color: theme.destructive, label: "Auth expired")
        } else {
            statusLabel(color: theme.success, label: "Active")
        }
    }

    private func statusLabel(color: Color, label: LocalizedStringKey) -> some View {
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

    private var headerActions: some View {
        HStack(spacing: 4) {
            AppIconButton(systemName: "arrow.triangle.2.circlepath",
                          help: "Check this account now",
                          spinOnTap: true) {
                fetcher?.fetch()
            }
            AppIconButton(systemName: "arrow.up.forward.app",
                          help: "Open inbox in browser") {
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
                    TextField("e.g. Work, Personal, Family", text: $friendlyNameDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.foreground)
                        .focused($friendlyFieldFocused)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .fill(theme.cardInset)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .strokeBorder(theme.borderStrong, lineWidth: 1)
                        )
                        .frame(width: 240)
                        .onSubmit {
                            FriendlyNameStore.shared.setName(friendlyNameDraft, for: account.email)
                        }
                }

                AppRowDivider().padding(.vertical, 12)

                AppSettingRow("Email address") {
                    Text(account.email)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.muted)
                        .textSelection(.enabled)
                }
            }
        }
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
                        .tint(theme.primary)
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
                        .appBoxedPicker()
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
                    .appBoxedPicker()
                }

                AppRowDivider().padding(.vertical, 12)

                AppSettingRow(
                    "Check for new mail every",
                    description: "Polling interval in minutes (1 – 900)."
                ) {
                    HStack(spacing: 0) {
                        Button(action: { account.checkInterval = max(1, account.checkInterval - 1) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.muted)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 32, height: 28)

                        Rectangle()
                            .fill(theme.borderStrong)
                            .frame(width: 1, height: 28)

                        Text(LocalizedStringKey("\(Int(account.checkInterval)) min"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Rectangle()
                            .fill(theme.borderStrong)
                            .frame(width: 1, height: 28)

                        Button(action: { account.checkInterval = min(900, account.checkInterval + 1) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.muted)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 32, height: 28)
                    }
                    .frame(width: 200, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(theme.cardInset)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .strokeBorder(theme.borderStrong, lineWidth: 1)
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
                        .tint(theme.primary)
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
                    AppSecondaryButton(title: "Remove", systemImage: "trash", tint: .destructive) {
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
