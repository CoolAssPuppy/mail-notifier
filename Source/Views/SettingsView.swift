//
//  SettingsView.swift
//  Mail Notifier
//
//  App-wide preferences rendered as a two-column card grid. Used by
//  `SettingsDrawer` to slide down over the main window. Retains every
//  original setting: launch-at-login, unread-count-in-menu-bar,
//  open-on-start, VIP list, global shortcut, Sparkle auto-update,
//  support links, and About info.
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

    @State private var newVIPEmail = ""
    @State private var newVIPSound = ""

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
                    supportCard
                    aboutCard
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
                        .tint(Color.appPrimary)
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
                        .tint(Color.appPrimary)
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
                        .tint(Color.appPrimary)
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
                .foregroundStyle(Color.appMuted)
                .padding(.bottom, 10)

            HStack(spacing: 6) {
                TextField("Email address", text: $newVIPEmail)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .fill(Color.appCardInset)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .strokeBorder(Color.appBorderStrong, lineWidth: 1)
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
                        .foregroundStyle(canAddVIP ? Color.appForeground : Color.appDim)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                .fill(Color.appCardElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                .strokeBorder(Color.appBorderStrong, lineWidth: 1)
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
                               onDelete: { vipList.delete(vip: vip) })
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
        newVIPEmail = ""
        newVIPSound = ""
    }

    // MARK: - Updates

    private var updatesCard: some View {
        AppCard("Updates", trailing: {
            HStack(spacing: 5) {
                Circle().fill(Color.appSuccess).frame(width: 5, height: 5)
                Text("UP TO DATE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Color.appSuccess)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.appSuccess.opacity(0.10))
            )
            .overlay(
                Capsule().strokeBorder(Color.appSuccess.opacity(0.3), lineWidth: 1)
            )
        }) {
            VStack(spacing: 0) {
                AppSettingRow(
                    "Check for updates automatically",
                    description: "Sparkle checks once a day, prompts before installing."
                ) {
                    Toggle("", isOn: $updater.automaticallyChecksForUpdates)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Color.appPrimary)
                }

                AppRowDivider().padding(.vertical, 10)

                AppSettingRow(
                    "Current version \(appVersion)",
                    description: "Sparkle-managed auto-update."
                ) {
                    AppSecondaryButton(title: "Check now", systemImage: "arrow.down.circle") {
                        UpdaterManager.shared.checkForUpdates()
                    }
                }
            }
        }
    }

    // MARK: - Support

    private var supportCard: some View {
        AppCard("Support") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mail Notifier is built by one person. Google charges indie email apps $8,000 per year for certification. If this app saves you time, please consider buying me a coffee.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appForegroundSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Link(destination: URL(string: "https://venmo.com/coolasspuppy")!) {
                        HStack(spacing: 7) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 11))
                            Text("Buy me a coffee")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccentOrange, Color.appAccentOrangeDeep],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    Link(destination: URL(string: "https://github.com/CoolAssPuppy/mail-notifier")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "star")
                                .font(.system(size: 11))
                            Text("Star on GitHub")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.appForeground)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .fill(Color.appCardInset)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .strokeBorder(Color.appBorderStrong, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        AppCard("About") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.appPrimary, Color.appPrimaryDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mail Notifier")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appForeground)
                        Text("A native mail watcher for Gmail and Outlook.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appMuted)

                        HStack(spacing: 8) {
                            Text(appVersion)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.appForeground)
                                .monospacedDigit()
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color.appCardInset)
                                )
                                .overlay(
                                    Capsule().strokeBorder(Color.appBorderStrong, lineWidth: 1)
                                )
                            Text("macOS 14+")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.appTertiary)
                        }
                        .padding(.top, 3)
                    }

                    Spacer()
                }

                AppRowDivider()

                VStack(alignment: .leading, spacing: 5) {
                    Text("Made with care by Strategic Nerds, Inc.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appForegroundSoft)
                    Text("© 2025 Strategic Nerds, Inc.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appForegroundSoft)
                    Link("Contribute on GitHub", destination: URL(string: "https://github.com/CoolAssPuppy/mail-notifier")!)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// MARK: - VIP Row

private struct VIPRow: View {
    let vip: VIP
    let onUpdate: (VIP) -> Void
    let onDelete: () -> Void

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
                .foregroundStyle(Color.appWarning)
            Text(vip.email)
                .font(.system(size: 12))
                .foregroundStyle(Color.appForeground)
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
            AppIconButton(systemName: "trash", tint: .appDestructive, action: onDelete)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    SettingsView()
        .frame(width: 980, height: 560)
        .background(Color.appSurface)
}
