//
//  SettingsView.swift
//  Mail Notifier
//
//  Created by James Chen on 2021/06/18.
//  Copyright © 2021 ashchan.com. All rights reserved.
//

import SwiftUI
import LaunchAtLogin
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable
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
            sectionHeader(icon: "gearshape.fill", title: "General", gradient: [.blue, .cyan])

            VStack(alignment: .leading, spacing: 12) {
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
                .onChange(of: showUnreadCount) { newValue in
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
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }

    private var vipSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "star.fill", title: "VIP List", gradient: [.yellow, .orange])

            VStack(alignment: .leading, spacing: 12) {
                Text("Get special notification sounds for emails from VIP senders")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Add new VIP form
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
                    .onChange(of: newVIPSound) { newValue in
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
                    Divider()
                        .padding(.vertical, 4)

                    ForEach(vipList) { vip in
                        VIPRow(vip: vip, onUpdate: { updated in
                            vipList.update(vip: updated)
                        }, onDelete: {
                            vipList.delete(vip: vip)
                        })
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
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
            sectionHeader(icon: "command.circle.fill", title: "Keyboard Shortcuts", gradient: [.purple, .pink])

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Check All Mails")
                        .font(.body)
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .checkAllMails)
                }

                Divider()

                HStack {
                    Text("Compose Mail")
                        .font(.body)
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .composeMail)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            infoBox
        }
    }

    private var infoBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Global Shortcuts")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("These keyboard shortcuts work globally across all applications. Click the recorder field and press your desired key combination to set a shortcut.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
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
            .onChange(of: selectedSound) { newValue in
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
