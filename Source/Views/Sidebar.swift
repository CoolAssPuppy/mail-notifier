//
//  Sidebar.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct Sidebar: View {
    // FriendlyNameStore is observed inside SidebarAccountRow where the name
    // is actually rendered, so it doesn't need to be observed here too.
    @AppStorage(Accounts.storageKey) var accounts = Accounts()
    @Environment(\.theme) private var theme
    @Binding var selection: String?
    var totalUnread: Int = 0
    var onOpenSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            brandHeader

            sectionLabel

            accountsList

            Spacer(minLength: 0)

            footer
        }
        .frame(maxHeight: .infinity)
        .background(theme.surface)
        .overlay(
            Rectangle()
                .fill(theme.divider)
                .frame(width: 1),
            alignment: .trailing
        )
    }

    // MARK: - Header

    private var brandHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.primary, theme.primaryDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "envelope.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text("Mail Notifier")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text(accounts.isEmpty
                     ? LocalizedStringKey("Setup required")
                     : LocalizedStringKey("\(accounts.count) configured"))
                    .font(.system(size: 10))
                    .foregroundStyle(theme.muted)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 10)
    }

    private var sectionLabel: some View {
        HStack {
            Text("ACCOUNTS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(theme.tertiary)
            Spacer()
            if totalUnread > 0 {
                Text("\(totalUnread) unread")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.warning)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    // MARK: - Accounts list

    private var accountsList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(accounts) { account in
                    SidebarAccountRow(
                        account: account,
                        isSelected: selection == account.email,
                        unreadCount: unreadCount(for: account)
                    )
                    .onTapGesture {
                        selection = account.email
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func unreadCount(for account: Account) -> Int {
        FetcherManager.shared.fetcher(for: account.email)?.unreadMessagesCount ?? 0
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: { selection = "welcome" }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(theme.foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(theme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(theme.borderStrong)
                )
            }
            .buttonStyle(.plain)

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.muted)
                    .frame(width: 34, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(theme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .strokeBorder(theme.borderStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help(LocalizedStringKey("Settings (⌘,)"))
        }
        .padding(12)
        .overlay(
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Row

private struct SidebarAccountRow: View {
    let account: Account
    let isSelected: Bool
    let unreadCount: Int

    @ObservedObject private var friendlyNames = FriendlyNameStore.shared
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ProviderBadge(type: account.type, size: 22, dimmed: !account.enabled)

            VStack(alignment: .leading, spacing: 1) {
                Text(account.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            trailingBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .strokeBorder(
                    isSelected ? theme.primary.opacity(0.25) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .opacity(account.enabled ? 1 : 0.55)
    }

    private var subtitle: String {
        account.friendlyName != nil ? account.email : account.type.displayLabel
    }

    private var textColor: Color {
        isSelected ? theme.foreground : theme.foregroundSoft
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(theme.primary.opacity(0.10))
        } else if isHovered {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.02))
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if !account.enabled {
            Text("Off")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(theme.cardElevated)
                )
        } else if unreadCount > 0 {
            Text("\(unreadCount)")
                .font(.system(size: 9, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(theme.background)
                .frame(minWidth: 18, minHeight: 18)
                .padding(.horizontal, 5)
                .background(Capsule().fill(theme.warning))
        }
    }
}

#Preview {
    Sidebar(
        accounts: [Account(email: "user@example.com", type: .gmail)],
        selection: .constant("user@example.com")
    )
    .frame(width: 260, height: 560)
}
