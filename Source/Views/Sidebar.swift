//
//  Sidebar.swift
//  Mail Notifier
//
//  Left-hand account list inside the main window. Selecting a row drives the
//  detail pane; the "Add account" button surfaces the welcome flow.
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct Sidebar: View {
    @AppStorage(Accounts.storageKey) var accounts = Accounts()
    @Binding var selection: String?
    var totalUnread: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            brandHeader

            sectionLabel

            accountsList

            Spacer(minLength: 0)

            footer
        }
        .frame(maxHeight: .infinity)
        .background(Color.appSurface)
        .overlay(
            Rectangle()
                .fill(Color.appDivider)
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
                            colors: [Color.appPrimary, Color.appPrimaryDeep],
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
                    .foregroundStyle(Color.appForeground)
                Text(accounts.isEmpty ? "Setup required" : "\(accounts.count) configured")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appMuted)
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
                .foregroundStyle(Color.appTertiary)
            Spacer()
            if totalUnread > 0 {
                Text("\(totalUnread) unread")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.appWarning)
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
        VStack(spacing: 8) {
            Button(action: { selection = "welcome" }) {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add account")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.appForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(Color.appCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Color.appBorderStrong)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appMuted)
                Text("Check all (⌥⌘N)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appMuted)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .overlay(
            Rectangle()
                .fill(Color.appDivider)
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

    @State private var isHovered = false
    @State private var friendlyNameTick = 0

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
                    .foregroundStyle(Color.appTertiary)
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
                    isSelected ? Color.appPrimary.opacity(0.25) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .opacity(account.enabled ? 1 : 0.55)
        .id(friendlyNameTick) // refresh label when iCloud KVS changes
        .onReceive(NotificationCenter.default.publisher(for: .friendlyNamesChanged)) { _ in
            friendlyNameTick += 1
        }
    }

    private var subtitle: String {
        if account.friendlyName != nil {
            return account.email
        }
        return account.type == .gmail ? "Gmail" : "Outlook"
    }

    private var textColor: Color {
        isSelected ? Color.appForeground : Color.appForegroundSoft
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(Color.appPrimary.opacity(0.10))
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
                .foregroundStyle(Color.appTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color.appCardElevated)
                )
        } else if unreadCount > 0 {
            Text("\(unreadCount)")
                .font(.system(size: 9, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.appBackground)
                .frame(minWidth: 18, minHeight: 18)
                .padding(.horizontal, 5)
                .background(Capsule().fill(Color.appWarning))
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
