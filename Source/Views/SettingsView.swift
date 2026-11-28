//
//  SettingsView.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var themeStore = ThemeStore.shared
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @StateObject private var demoMode = DemoMode.shared
    #if !MAC_APP_STORE
    @StateObject private var updater = UpdaterManager.shared
    #endif
    @AppStorage(AppSettings.showUnreadCount) private var showUnreadCount = AppSettings.shared.showUnreadCount
    @AppStorage(AppSettings.openSettingsOnStartKey) private var openSettingsOnStart = false
    @AppStorage(AppSettings.recentMessageCountKey) private var recentMessageCount = AppSettings.defaultRecentMessageCount
    @AppStorage(AppSettings.compactModeKey) private var compactMode = false
    @AppStorage(AppSettings.quietHoursEnabledKey) private var quietHoursEnabled = false
    @AppStorage(AppSettings.quietHoursStartKey) private var quietStartMinute = AppSettings.defaultQuietHoursStart
    @AppStorage(AppSettings.quietHoursEndKey) private var quietEndMinute = AppSettings.defaultQuietHoursEnd
    @AppStorage(VIPList.storageKey) private var vipList = VIPList()

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var privacyExpanded: Bool
    @State private var privacyCopied = false
    @State private var newVIPEmail = ""
    @State private var newVIPSound = ""
    @State private var telemetryOptIn: Bool = Telemetry.isOptedIn
    @State private var shareLinkCopied = false

    var body: some View {
        VStack(spacing: 14) {
            generalCard
            notificationsCard
            appearanceCard
            keyboardCard
            vipCard
            #if MAC_APP_STORE
            TipCard()
            #else
            SubscriptionCard()
            #endif
            updatesCard
            contactCard
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var notificationsCard: some View {
        AppCard("Notifications") {
            VStack(alignment: .leading, spacing: 12) {
                AppSettingRow("Quiet hours", description: "Pause alerts and sounds. Mail checks continue.") {
                    Toggle("", isOn: $quietHoursEnabled)
                        .labelsHidden()
                        .accessibilityLabel("Quiet hours")
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.primary)
                }

                if quietHoursEnabled {
                    HStack(spacing: 16) {
                        DatePicker("From", selection: quietTimeBinding(isStart: true),
                                   displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: quietTimeBinding(isStart: false),
                                   displayedComponents: .hourAndMinute)
                    }
                    .datePickerStyle(.field)

                    if quietStartMinute == quietEndMinute {
                        Text("Choose different start and end times.")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.warning)
                    }
                }
            }
        }
    }

    private func quietTimeBinding(isStart: Bool) -> Binding<Date> {
        Binding(
            get: {
                let minute = isStart ? quietStartMinute : quietEndMinute
                return QuietHours.pickerDate(for: minute)
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                if isStart {
                    quietStartMinute = minute
                } else {
                    quietEndMinute = minute
                }
            }
        )
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
                        .accessibilityLabel("Launch at login")
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
                        .accessibilityLabel("Show unread count in menu bar")
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.primary)
                        .onChange(of: showUnreadCount) { _, _ in
                            AppSettings.shared.showUnreadCountSettingChanged()
                        }
                }

                AppRowDivider().padding(.vertical, 10)

                AppSettingRow(
                    "Show recent messages",
                    description: "How many messages to list under each account."
                ) {
                    AppStepper(value: $recentMessageCount,
                               range: AppSettings.recentMessageRange,
                               width: 104)
                        .accessibilityLabel("Show recent messages")
                }

                AppRowDivider().padding(.vertical, 10)

                AppSettingRow(
                    "Open main window on launch",
                    description: "Otherwise the app stays in the menu bar."
                ) {
                    Toggle("", isOn: $openSettingsOnStart)
                        .labelsHidden()
                        .accessibilityLabel("Open main window on launch")
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.primary)
                }

                AppRowDivider().padding(.vertical, 10)

                AppSettingRow(
                    "Compact mode",
                    description: "Only show accounts with new mail"
                ) {
                    Toggle("", isOn: $compactMode)
                        .labelsHidden()
                        .accessibilityLabel("Compact mode")
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.primary)
                        .onChange(of: compactMode) { _, _ in
                            AppSettings.shared.compactModeSettingChanged()
                        }
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
                    .accessibilityLabel("Send anonymous usage data")
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
            AppSettingRow("Check all mail", description: nil) {
                KeyboardShortcuts.Recorder(for: .checkAllMails)
            }
        }
    }

    // MARK: - VIP

    private var vipCard: some View {
        AppCard("VIP List") {
            Text("Custom notification sounds for important senders.")
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
                .accessibilityLabel("Sound")
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
                .accessibilityLabel("Add")
            }

            if !vipList.isEmpty {
                VStack(spacing: 0) {
                    ForEach(vipList) { vip in
                        VIPRow(vip: vip,
                               onUpdate: { vipList.update(vip: $0) },
                               onDelete: {
                                   vipList.delete(vip: vip)
                                   Telemetry.capture(.vipRemoved)
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
        Telemetry.capture(.vipAdded)
        newVIPEmail = ""
        newVIPSound = ""
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        AppCard("Appearance") {
            AppSettingRow("Theme") {
                ThemeSelector(selection: $themeStore.current)
            }

            AppRowDivider().padding(.vertical, 12)

            Text("Menu Style")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.foreground)
                .padding(.bottom, 10)
            MenuStylePicker()
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
    }

    // MARK: - Updates

    private var updatesCard: some View {
        #if MAC_APP_STORE
        AppCard("Updates") {
            versionRow()
        }
        #else
        AppCard("Updates") {
            VStack(spacing: 0) {
                AppSettingRow("Automatically check for updates", description: nil) {
                    Toggle("", isOn: $updater.automaticallyChecksForUpdates)
                        .labelsHidden()
                        .accessibilityLabel("Automatically check for updates")
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.primary)
                }

                AppRowDivider().padding(.vertical, 10)

                versionRow()

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
        #endif
    }

    private func versionRow() -> some View {
        AppSettingRow("Current version", description: nil) {
            Text(appVersion)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(demoMode.isOn ? theme.warning : theme.foreground)
        }
        .contextMenu {
            Button(demoMode.isOn ? "Turn Demo Mode off" : "Turn Demo Mode on") {
                demoMode.toggle()
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
                AppSecondaryButton(title: shareLinkCopied ? "Copied" : "Share Mail Notifier with friends",
                                   systemImage: shareLinkCopied ? "checkmark" : "square.and.arrow.up") {
                    SharePromptStore().copyLink(from: .settings)
                    shareLinkCopied = true
                }
                .task(id: shareLinkCopied) {
                    guard shareLinkCopied else { return }
                    try? await Task.sleep(for: .seconds(1.8))
                    if !Task.isCancelled { shareLinkCopied = false }
                }
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
                    title: "Contribute on GitHub",
                    url: "https://github.com/CoolAssPuppy/mail-notifier"
                )
                privacyInformation
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

    private static let privacyStatement = NSLocalizedString("""
        Mail Notifier connects directly to Google and Microsoft to check your inbox. It does not route your mail through a Mail Notifier server. Mail account sign-in tokens are stored in your macOS Keychain.

        You can turn off usage analytics and crash reporting in Settings under “Send anonymous usage data.” When enabled and configured, analytics report app usage and sign-in error codes. Crash reports may include technical details about the app and your Mac.

        If iCloud is available, your custom account names and icons can sync across your Macs through Apple’s iCloud. The sync uses email addresses to match these settings to accounts. This sync does not send mail or sign-in tokens.

        If you see behavior that differs from this statement, please report it to bugs@strategicnerds.com.
        """, comment: "Copyable text in the Security and privacy information panel")

    private var privacyInformation: some View {
        VStack(alignment: .leading, spacing: 8) {
            if privacyExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Self.privacyStatement)
                        .font(.callout)
                        .foregroundStyle(theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        AppSecondaryButton(title: privacyCopied ? "Copied" : "Copy",
                                           systemImage: privacyCopied ? "checkmark" : "doc.on.doc") {
                            NSPasteboard.general.clearContents()
                            privacyCopied = NSPasteboard.general.setString(Self.privacyStatement, forType: .string)
                        }
                        Button("Dismiss") { setPrivacyExpanded(false) }
                            .keyboardShortcut(.cancelAction)
                    }
                }
                .padding(12)
                .frame(maxWidth: 490, alignment: .leading)
                .background(theme.cardElevated, in: RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay { RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(theme.border) }
                .transition(reduceMotion ? .identity : .scale(scale: 0.08, anchor: .bottomLeading).combined(with: .opacity))
            }

            Button { setPrivacyExpanded(!privacyExpanded) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(theme.muted)
                        .frame(width: 16)
                        .accessibilityHidden(true)
                    Text("Security and privacy information")
                        .foregroundStyle(theme.primary)
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .accessibilityValue(privacyExpanded ? Text("Expanded") : Text("Collapsed"))
        }
        .id("security-and-privacy")
    }

    private func setPrivacyExpanded(_ expanded: Bool) {
        privacyCopied = false
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.28)) {
            privacyExpanded = expanded
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
            .accessibilityLabel("Notification sound")
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
    SettingsView(privacyExpanded: .constant(false))
        .frame(width: 980, height: 560)
}
