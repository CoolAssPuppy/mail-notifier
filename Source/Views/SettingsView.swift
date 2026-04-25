//
//  SettingsView.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @StateObject private var updater = UpdaterManager.shared
    @AppStorage(AppSettings.showUnreadCount) private var showUnreadCount = AppSettings.shared.showUnreadCount
    @AppStorage(AppSettings.openSettingsOnStartKey) private var openSettingsOnStart = false
    @AppStorage(VIPList.storageKey) private var vipList = VIPList()

    @Environment(\.theme) private var theme
    @State private var newVIPEmail = ""
    @State private var newVIPSound = ""
    @State private var telemetryOptIn: Bool = Telemetry.isOptedIn

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 14) {
                    generalCard
                    keyboardCard
                    vipCard
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    updatesCard
                    contactCard
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 14)
        }
    }

    // MARK: - General

    private var generalCard: some View {
        AppCard("General") {
            VStack(spacing: 0) {
                AppSettingRow(
                    "Launch at login",
                    description: "Start Mail Notifier when you log in."
                ) {
                    Toggle("", isOn: $launchAtLogin.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.primary)
                }

                AppRowDivider().padding(.vertical, 10)

                AppSettingRow(
                    "Show unread count in menu bar",
                    description: "Display total unread next to the icon."
                ) {
                    Toggle("", isOn: $showUnreadCount)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.primary)
                        .onChange(of: showUnreadCount) { _, _ in
                            AppSettings.shared.showUnreadCountSettingChanged()
                        }
                }

                AppRowDivider().padding(.vertical, 10)

                AppSettingRow(
                    "Open main window on launch",
                    description: "Otherwise the app stays in the menu bar."
                ) {
                    Toggle("", isOn: $openSettingsOnStart)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.primary)
                }

                AppRowDivider().padding(.vertical, 10)

                AppSettingRow(
                    "Send anonymous usage data",
                    description: "Help improve Mail Notifier."
                ) {
                    Toggle("", isOn: Binding(
                        get: { telemetryOptIn },
                        set: { newValue in
                            telemetryOptIn = newValue
                            Telemetry.setOptedIn(newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(theme.primary)
                }
            }
        }
    }

    // MARK: - Keyboard

    private var keyboardCard: some View {
        AppCard("Keyboard Shortcuts") {
            AppSettingRow(
                "Check all mail",
                description: "Global shortcut, works in any app."
            ) {
                KeyboardShortcuts.Recorder(for: .checkAllMails)
            }
        }
    }

    // MARK: - VIP

    private var vipCard: some View {
        AppCard("VIP List") {
            Text("Custom notification sounds for important senders. Plays in any account.")
                .font(.system(size: 10))
                .foregroundStyle(theme.muted)
                .padding(.bottom, 10)

            HStack(spacing: 6) {
                TextField("Email address", text: $newVIPEmail)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.foreground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .fill(theme.cardInset)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .strokeBorder(theme.borderStrong, lineWidth: 1)
                    )

                Picker("", selection: $newVIPSound) {
                    Text("Sound").tag("")
                    Divider()
                    ForEach(Sound.allCases) { sound in
                        Text(sound.name).tag(sound.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 130)
                .onChange(of: newVIPSound) { _, newValue in
                    Sound(rawValue: newValue)?.nsSound?.play()
                }

                Button(action: addVIP) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(canAddVIP ? theme.foreground : theme.dim)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                .fill(theme.cardElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                .strokeBorder(theme.borderStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canAddVIP)
            }

            if !vipList.isEmpty {
                VStack(spacing: 0) {
                    ForEach(vipList) { vip in
                        VIPRow(vip: vip,
                               onUpdate: { vipList.update(vip: $0) },
                               onDelete: {
                                   vipList.delete(vip: vip)
                                   Telemetry.capture("vip.removed")
                               })
                        if vip.id != vipList.last?.id {
                            AppRowDivider()
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private var canAddVIP: Bool {
        !newVIPEmail.trimmingCharacters(in: .whitespaces).isEmpty && !newVIPSound.isEmpty
    }

    private func addVIP() {
        let vip = VIP(email: newVIPEmail.trimmingCharacters(in: .whitespaces),
                      notificationSound: newVIPSound)
        vipList.add(vip: vip)
        Telemetry.capture("vip.added")
        newVIPEmail = ""
        newVIPSound = ""
    }

    // MARK: - Updates

    private var updatesCard: some View {
        AppCard("Updates") {
            VStack(spacing: 0) {
                AppSettingRow("Automatically check for updates", description: nil) {
                    Toggle("", isOn: $updater.automaticallyChecksForUpdates)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.primary)
                }

                AppRowDivider().padding(.vertical, 10)

                AppSettingRow("Current version", description: nil) {
                    Text(appVersion)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.foreground)
                }

                AppRowDivider().padding(.vertical, 10)

                Button { UpdaterManager.shared.checkForUpdates() } label: {
                    Text("Check for updates…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .strokeBorder(theme.borderStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    // MARK: - Contact

    private var contactCard: some View {
        AppCard("Contact") {
            VStack(alignment: .leading, spacing: 10) {
                contactRow(
                    iconView: AnyView(
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.muted)
                    ),
                    title: "bugs@strategicnerds.com",
                    url: "mailto:bugs@strategicnerds.com"
                )
                contactRow(
                    iconView: AnyView(
                        Image("GitHubMark")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                            .foregroundStyle(theme.muted)
                    ),
                    title: "coolasspuppy/mail-notifier",
                    url: "https://github.com/CoolAssPuppy/mail-notifier"
                )
                contactRow(
                    iconView: AnyView(
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.muted)
                    ),
                    title: "Buy me coffee",
                    url: "https://venmo.com/u/coolasspuppy"
                )
                contactRow(
                    iconView: AnyView(
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.muted)
                    ),
                    title: "Buy my book",
                    url: "https://www.strategicnerds.com/picksandshovels"
                )
            }
        }
    }

    private func contactRow(iconView: AnyView, title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 8) {
                iconView
                    .frame(width: 16, alignment: .center)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - VIP Row

private struct VIPRow: View {
    let vip: VIP
    let onUpdate: (VIP) -> Void
    let onDelete: () -> Void

    @Environment(\.theme) private var theme
    @State private var selectedSound: String

    init(vip: VIP, onUpdate: @escaping (VIP) -> Void, onDelete: @escaping () -> Void) {
        self.vip = vip
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._selectedSound = State(initialValue: vip.notificationSound)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(theme.warning)
            Text(vip.email)
                .font(.system(size: 12))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
            Spacer()
            Picker("", selection: $selectedSound) {
                ForEach(Sound.allCases) { sound in
                    Text(sound.name).tag(sound.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 110)
            .onChange(of: selectedSound) { _, newValue in
                Sound(rawValue: newValue)?.nsSound?.play()
                var updated = vip
                updated.notificationSound = newValue
                onUpdate(updated)
            }
            AppIconButton(systemName: "trash", tint: .destructive, action: onDelete)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    SettingsView()
        .frame(width: 980, height: 560)
}
