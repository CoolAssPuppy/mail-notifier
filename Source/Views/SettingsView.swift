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
    @AppStorage(AppSettings.showUnreadCount) var showUnreadCount = AppSettings.shared.showUnreadCount
    @AppStorage(AppSettings.openSettingsOnStartKey) var openSettingsOnStart = false
    @AppStorage(VIPList.storageKey) var vipList = VIPList()

    @State private var newVIPEmail = ""
    @State private var newVIPSound = ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    generalSection

                    Divider()
                        .padding(.vertical, 8)

                    vipSection

                    Divider()
                        .padding(.vertical, 8)

                    shortcutsSection

                    Divider()
                        .padding(.vertical, 8)

                    updatesSection

                    Divider()
                        .padding(.vertical, 8)

                    supportSection

                    Divider()
                        .padding(.vertical, 8)

                    aboutSection

                    Spacer()
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.02),
                        Color.clear,
                        Color.blue.opacity(0.01)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private var headerBar: some View {
        HStack {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding()
        .background(.regularMaterial)
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "gearshape.fill", title: "General", gradient: [.blue, .cyan])

            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $launchAtLogin.isEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch at login")
                            .font(.body)
                        Text("Automatically start Mail Notifier when you log in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $showUnreadCount) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show unread count in menu bar")
                            .font(.body)
                        Text("Display the number of unread messages next to the menu bar icon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: showUnreadCount) { _, _ in
                    AppSettings.shared.showUnreadCountSettingChanged()
                }

                Toggle(isOn: $openSettingsOnStart) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open Settings window on start")
                            .font(.body)
                        Text("Show this window when the app launches")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 4)
        }
    }

    private var vipSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "star.fill", title: "VIP List", gradient: [.yellow, .orange])

            VStack(alignment: .leading, spacing: 12) {
                Text("Get special notification sounds for emails from VIP senders")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("Email address", text: $newVIPEmail)
                        .textFieldStyle(.roundedBorder)

                    Picker("", selection: $newVIPSound) {
                        Text("Select sound").tag("")
                        Divider()
                        ForEach(Sound.allCases) { sound in
                            Text(sound.name).tag(sound.rawValue)
                        }
                    }
                    .frame(width: 140)
                    .onChange(of: newVIPSound) { _, newValue in
                        if let sound = Sound(rawValue: newValue) {
                            sound.nsSound?.play()
                        }
                    }

                    Button {
                        addVIP()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .disabled(newVIPEmail.isEmpty || newVIPSound.isEmpty)
                }

                if !vipList.isEmpty {
                    ForEach(vipList) { vip in
                        VIPRow(vip: vip, onUpdate: { updated in
                            vipList.update(vip: updated)
                        }, onDelete: {
                            vipList.delete(vip: vip)
                        })
                    }
                }
            }
            .padding(.leading, 4)
        }
    }

    private func addVIP() {
        let vip = VIP(email: newVIPEmail.trimmingCharacters(in: .whitespaces), notificationSound: newVIPSound)
        vipList.add(vip: vip)
        newVIPEmail = ""
        newVIPSound = ""
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "command.circle.fill", title: "Keyboard Shortcuts", gradient: [.purple, .pink])

            VStack(alignment: .leading, spacing: 12) {
                Text("These shortcuts work globally across all applications")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Check All Mails")
                        .font(.body)
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .checkAllMails)
                }
            }
            .padding(.leading, 4)
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "arrow.triangle.2.circlepath", title: "Updates", gradient: [.purple, .indigo])

            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $updater.automaticallyChecksForUpdates) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check for updates automatically")
                            .font(.body)
                        Text("Mail Notifier checks once a day and prompts you before installing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    UpdaterManager.shared.checkForUpdates()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text("Check for Updates Now")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(!updater.canCheckForUpdates)
            }
            .padding(.leading, 4)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "cup.and.saucer.fill", title: "Support", gradient: [.brown, .orange])

            VStack(alignment: .leading, spacing: 8) {
                Link(destination: URL(string: "https://venmo.com/coolasspuppy")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "cup.and.saucer.fill")
                        Text("Buy Me Coffee on Venmo")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Text("Support independent development. Google forces indie developers building email apps to pay USD $8000 to be certified every year. This app depends on your generosity.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 4)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "info.circle.fill", title: "About", gradient: [.gray, .secondary])

            VStack(alignment: .leading, spacing: 6) {
                Text("Made with love by Strategic Nerds, Inc.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("© 2025 Strategic Nerds, Inc.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Link("Contribute on GitHub", destination: URL(string: "https://github.com/CoolAssPuppy/mail-notifier")!)
                    .font(.caption)
            }
            .padding(.leading, 4)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

}

struct VIPRow: View {
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
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.caption)

            Text(vip.email)
                .font(.body)
                .lineLimit(1)

            Spacer()

            Picker("", selection: $selectedSound) {
                ForEach(Sound.allCases) { sound in
                    Text(sound.name).tag(sound.rawValue)
                }
            }
            .frame(width: 120)
            .onChange(of: selectedSound) { _, newValue in
                if let sound = Sound(rawValue: newValue) {
                    sound.nsSound?.play()
                }
                var updated = vip
                updated.notificationSound = newValue
                onUpdate(updated)
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
}
