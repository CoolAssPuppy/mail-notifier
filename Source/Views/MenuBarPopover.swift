//
//  MenuBarPopover.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - View Model

final class MenuBarPopoverModel: ObservableObject {
    struct AccountState: Identifiable, Equatable {
        let account: Account
        let unreadCount: Int
        let hasAuthError: Bool
        let recentMessages: [Message]
        let lastCheckedAt: Date?

        var id: String { account.email }

        static func == (lhs: AccountState, rhs: AccountState) -> Bool {
            guard lhs.account.email == rhs.account.email else { return false }
            guard lhs.account.enabled == rhs.account.enabled else { return false }
            guard lhs.unreadCount == rhs.unreadCount else { return false }
            guard lhs.hasAuthError == rhs.hasAuthError else { return false }
            guard lhs.lastCheckedAt == rhs.lastCheckedAt else { return false }
            let lhsIds = lhs.recentMessages.map(\.id)
            let rhsIds = rhs.recentMessages.map(\.id)
            return lhsIds == rhsIds
        }
    }

    @Published private(set) var accountStates: [AccountState] = []
    @Published private(set) var totalUnread: Int = 0
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var vipEmails: Set<String> = []

    private let fetcherManager = FetcherManager.shared
    private var subscriptions = Set<AnyCancellable>()
    private static let recentMessageLimit = 3

    init() {
        refresh()
        refreshVIPs()
        subscribe()
    }

    func refresh() {
        let next: [AccountState] = Accounts.default.map { account in
            let fetcher = fetcherManager.fetcher(for: account.email)
            let messages = (fetcher?.messages ?? []).prefix(Self.recentMessageLimit)
            return AccountState(
                account: account,
                unreadCount: fetcher?.unreadMessagesCount ?? 0,
                hasAuthError: fetcher?.hasAuthError ?? false,
                recentMessages: Array(messages),
                lastCheckedAt: fetcher?.lastCheckedAt
            )
        }

        guard next != accountStates else { return }

        accountStates = next
        totalUnread = next.reduce(0) { $0 + $1.unreadCount }
        lastCheckedAt = next.compactMap(\.lastCheckedAt).max()
    }

    private func refreshVIPs() {
        vipEmails = Set(VIPList.default.map { $0.email.lowercased() })
    }

    private func subscribe() {
        let accountNames: [Notification.Name] = [
            .accountAdded, .accountDeleted, .accountUpdated, .accountsReordered,
            .messagesFetched, .unreadCountUpdated, .friendlyNamesChanged
        ]

        Publishers.MergeMany(accountNames.map { NotificationCenter.default.publisher(for: $0) })
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &subscriptions)

        UserDefaults.standard.publisher(for: \.vipListRaw)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshVIPs() }
            .store(in: &subscriptions)
    }
}

private extension UserDefaults {
    @objc dynamic var vipListRaw: String? {
        string(forKey: VIPList.storageKey)
    }
}

// MARK: - Action Set

struct MenuBarPopoverActions {
    var openMessage: (Message) -> Void
    var openInbox: (Account) -> Void
    var reauthorize: (Account) -> Void
    var checkAll: () -> Void
    var openWindow: () -> Void
    var openSettings: () -> Void
    var quit: () -> Void
}

// MARK: - Root View

struct MenuBarPopover: View {
    @ObservedObject var model: MenuBarPopoverModel
    let actions: MenuBarPopoverActions

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(totalUnread: model.totalUnread, accountCount: model.accountStates.count)
            Divider().background(Color.appDivider)
            content
            Divider().background(Color.appDivider)
            BottomBar(actions: actions)
        }
        .frame(width: 380)
        .background(Color.appBackground)
    }

    @ViewBuilder
    private var content: some View {
        if model.accountStates.isEmpty {
            EmptyAccountsState(onAddAccount: actions.openWindow)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                AccountsListLabel(lastCheckedAt: model.lastCheckedAt)

                ForEach(model.accountStates) { state in
                    AccountCard(
                        state: state,
                        vipEmails: model.vipEmails,
                        onOpenInbox: { actions.openInbox(state.account) },
                        onOpenMessage: actions.openMessage,
                        onReauthorize: { actions.reauthorize(state.account) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Header

private struct HeaderBar: View {
    let totalUnread: Int
    let accountCount: Int

    var body: some View {
        HStack(spacing: 10) {
            BrandMark()

            VStack(alignment: .leading, spacing: 1) {
                Text("Mail Notifier")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appForeground)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.appSuccess)
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.appSuccess.opacity(0.5), radius: 4)
                    Text(statusLine)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appMuted)
                }
            }

            Spacer(minLength: 8)

            if totalUnread > 0 {
                UnreadPill(count: totalUnread)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.appSurface)
    }

    private var statusLine: String {
        switch accountCount {
        case 0: return "No accounts configured"
        case 1: return "1 account configured"
        default: return "\(accountCount) accounts configured"
        }
    }
}

private struct BrandMark: View {
    var body: some View {
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
        .frame(width: 22, height: 22)
    }
}

private struct UnreadPill: View {
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "tray.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.appWarning)
            Text("\(count) unread")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.appWarning)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.appWarning.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(Color.appWarning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Accounts list label

private struct AccountsListLabel: View {
    let lastCheckedAt: Date?

    var body: some View {
        HStack {
            Text("ACCOUNTS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.appTertiary)
            Spacer()
            if let timestamp = lastCheckedAt {
                Text("Last checked \(Formatters.shortTime.string(from: timestamp))")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }
}

// MARK: - Account Card

private struct AccountCard: View {
    let state: MenuBarPopoverModel.AccountState
    let vipEmails: Set<String>
    let onOpenInbox: () -> Void
    let onOpenMessage: (Message) -> Void
    let onReauthorize: () -> Void

    @State private var isExpanded = false
    @State private var isHovered = false

    private var canExpand: Bool {
        !state.hasAuthError && !state.recentMessages.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            if isExpanded && canExpand {
                Divider().background(Color.appBorder)
                messagesList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.appCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: isExpanded)
    }

    private var borderColor: Color {
        if state.hasAuthError {
            return Color.appDestructive.opacity(0.25)
        } else if isExpanded {
            return Color.appBorderFocus
        } else {
            return Color.appBorder
        }
    }

    private var headerRow: some View {
        Button(action: handleHeaderTap) {
            HStack(spacing: 10) {
                ProviderBadge(type: state.account.type, dimmed: state.hasAuthError)

                VStack(alignment: .leading, spacing: 1) {
                    Text(state.account.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appForeground)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    subtitle
                }

                Spacer(minLength: 8)

                trailingAccessory
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(headerBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if state.hasAuthError {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.appDestructive)
                Text("Authorization expired")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.appDestructive)
            }
        } else {
            Text(secondaryLine)
                .font(.system(size: 10))
                .foregroundStyle(Color.appMuted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var secondaryLine: String {
        let base = state.account.friendlyName != nil ? state.account.email : state.account.type.displayLabel
        if let timestamp = state.lastCheckedAt {
            return "\(base) · checked \(Formatters.shortTime.string(from: timestamp))"
        }
        return base
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if state.hasAuthError {
            Button(action: onReauthorize) {
                Text("Reauthorize")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.appDestructive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.appDestructive.opacity(0.12))
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.appDestructive.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 6) {
                if state.unreadCount > 0 {
                    Text("\(state.unreadCount) new")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appWarning)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.appWarning.opacity(0.12))
                        )
                        .overlay(
                            Capsule().strokeBorder(Color.appWarning.opacity(0.3), lineWidth: 1)
                        )
                }

                if canExpand {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.appTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeOut(duration: 0.18), value: isExpanded)
                }
            }
        }
    }

    @ViewBuilder
    private var headerBackground: some View {
        if isExpanded && canExpand {
            Color.appPrimary.opacity(0.06)
        } else if isHovered {
            Color.white.opacity(0.02)
        } else {
            Color.clear
        }
    }

    private var messagesList: some View {
        VStack(spacing: 1) {
            ForEach(state.recentMessages, id: \.id) { message in
                MessageRow(
                    message: message,
                    isVIP: vipEmails.contains(message.senderEmail)
                ) {
                    onOpenMessage(message)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func handleHeaderTap() {
        if state.hasAuthError { return }
        if canExpand {
            isExpanded.toggle()
        } else {
            onOpenInbox()
        }
    }
}

// MARK: - Provider Badge

struct ProviderBadge: View {
    let type: AccountType
    var size: CGFloat = 24
    var dimmed: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.appCardElevated)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.appBorderStrong, lineWidth: 1)
            Image(type.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.6, height: size * 0.6)
                .opacity(dimmed ? 0.45 : 1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: Message
    let isVIP: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    if isVIP {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.appWarning)
                    }
                    Text(message.sender)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appForeground)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(Formatters.relativeLabel(for: message.serverDate))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.appTertiary)
                        .monospacedDigit()
                }
                Text(snippetLine)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.appPrimary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var snippetLine: String {
        let subject = message.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return subject.isEmpty ? message.decodedSnippet : subject
    }
}

// MARK: - Empty State

private struct EmptyAccountsState: View {
    let onAddAccount: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appCard)
                Image(systemName: "envelope")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color.appMuted)
            }
            .frame(width: 56, height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            )

            VStack(spacing: 4) {
                Text("No accounts yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appForeground)
                Text("Add a Gmail or Outlook inbox to start watching your mail.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }

            Button(action: onAddAccount) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add account")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.appPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.appPrimary.opacity(0.12))
                )
                .overlay(
                    Capsule().strokeBorder(Color.appPrimary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

// MARK: - Bottom Bar

private struct BottomBar: View {
    let actions: MenuBarPopoverActions

    var body: some View {
        HStack(spacing: 4) {
            AppIconButton(systemName: "arrow.triangle.2.circlepath",
                          help: "Check all accounts now",
                          spinOnTap: true,
                          action: actions.checkAll)
            AppIconButton(systemName: "macwindow", help: "Open main window", action: actions.openWindow)
            AppIconButton(systemName: "gearshape", help: "Settings (⌘,)", action: actions.openSettings)

            Spacer(minLength: 0)

            AppIconButton(systemName: "power", help: "Quit Mail Notifier", action: actions.quit)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.appSurface)
    }
}
