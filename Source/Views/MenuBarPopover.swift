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
    @ObservedObject private var themeStore = ThemeStore.shared
    let actions: MenuBarPopoverActions

    var body: some View {
        let theme = themeStore.palette
        return VStack(spacing: 0) {
            HeaderBar(totalUnread: model.totalUnread, accountCount: model.accountStates.count)
            Divider().background(theme.divider)
            content
            Divider().background(theme.divider)
            BottomBar(actions: actions)
        }
        .frame(width: 380)
        .background(theme.background)
        .environment(\.theme, theme)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
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

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            BrandMark()

            VStack(alignment: .leading, spacing: 1) {
                Text("Mail Notifier")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                HStack(spacing: 6) {
                    Circle()
                        .fill(theme.success)
                        .frame(width: 6, height: 6)
                        .shadow(color: theme.success.opacity(0.5), radius: 4)
                    Text(statusLine)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.muted)
                }
            }

            Spacer(minLength: 8)

            if totalUnread > 0 {
                UnreadPill(count: totalUnread)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.surface)
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
    @Environment(\.theme) private var theme

    var body: some View {
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
        .frame(width: 22, height: 22)
    }
}

private struct UnreadPill: View {
    let count: Int

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "tray.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(theme.warning)
            Text("\(count) unread")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.warning)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(theme.warning.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(theme.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Accounts list label

private struct AccountsListLabel: View {
    let lastCheckedAt: Date?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text("ACCOUNTS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(theme.tertiary)
            Spacer()
            if let timestamp = lastCheckedAt {
                Text("Last checked \(Formatters.shortTime.string(from: timestamp))")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.tertiary)
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

    @Environment(\.theme) private var theme
    @State private var isExpanded = false
    @State private var isHovered = false

    private var canExpand: Bool {
        !state.hasAuthError && !state.recentMessages.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            if isExpanded && canExpand {
                Divider().background(theme.border)
                messagesList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.card)
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
            return theme.destructive.opacity(0.25)
        } else if isExpanded {
            return theme.borderFocus
        } else {
            return theme.border
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Button(action: openInboxTapped) {
                HStack(spacing: 10) {
                    ProviderBadge(type: state.account.type, size: 29, dimmed: state.hasAuthError)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.account.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        subtitle
                    }

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(state.hasAuthError ? "" : "Open inbox in browser")

            trailingAccessory
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(headerBackground)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var subtitle: some View {
        if state.hasAuthError {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.destructive)
                Text("Authorization expired")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.destructive)
            }
        } else {
            Text(secondaryLine)
                .font(.system(size: 10))
                .foregroundStyle(theme.muted)
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
                    .foregroundStyle(theme.destructive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(theme.destructive.opacity(0.12))
                    )
                    .overlay(
                        Capsule().strokeBorder(theme.destructive.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 6) {
                if state.unreadCount > 0 {
                    Text("\(state.unreadCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.warning)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(theme.warning.opacity(0.12))
                        )
                        .overlay(
                            Capsule().strokeBorder(theme.warning.opacity(0.3), lineWidth: 1)
                        )
                }

                if canExpand {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeOut(duration: 0.18), value: isExpanded)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "Hide recent messages" : "Show recent messages")
                }
            }
        }
    }

    @ViewBuilder
    private var headerBackground: some View {
        if isExpanded && canExpand {
            theme.primary.opacity(0.06)
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

    private func openInboxTapped() {
        if state.hasAuthError { return }
        onOpenInbox()
    }
}

// MARK: - Provider Badge

struct ProviderBadge: View {
    let type: AccountType
    var size: CGFloat = 24
    var dimmed: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(theme.cardElevated)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.borderStrong, lineWidth: 1)
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

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    if isVIP {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.warning)
                    }
                    Text(message.sender)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(Formatters.relativeLabel(for: message.serverDate))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.tertiary)
                        .monospacedDigit()
                }
                Text(snippetLine)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? theme.primary.opacity(0.08) : Color.clear)
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
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.card)
                Image(systemName: "envelope")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(theme.muted)
            }
            .frame(width: 56, height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1)
            )

            VStack(spacing: 4) {
                Text("No accounts yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text("Add a Gmail or Outlook inbox to start watching your mail.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.muted)
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
                .foregroundStyle(theme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(theme.primary.opacity(0.12))
                )
                .overlay(
                    Capsule().strokeBorder(theme.primary.opacity(0.3), lineWidth: 1)
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

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            AppIconButton(systemName: "arrow.triangle.2.circlepath",
                          help: "Check all accounts now",
                          spinOnTap: true,
                          action: actions.checkAll)
            AppIconButton(systemName: "macwindow", help: "Open main window", action: actions.openWindow)
            AppIconButton(systemName: "gearshape", help: "Settings (⌘,)", action: actions.openSettings)

            Spacer(minLength: 0)

            ThemeStrip()

            Spacer(minLength: 0)

            AppIconButton(systemName: "power", help: "Quit Mail Notifier", action: actions.quit)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(theme.surface)
    }
}

// MARK: - Theme Strip

private struct ThemeStrip: View {
    @ObservedObject private var store = ThemeStore.shared
    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    private static let bouncy: Animation = .spring(response: 0.35, dampingFraction: 0.6)
    private static let dotSize: CGFloat = 10

    var body: some View {
        HStack(spacing: isExpanded ? 6 : 0) {
            ForEach(AppTheme.allCases) { option in
                let palette = option.palette
                let isActive = store.current == option
                let show = isExpanded || isActive

                Button {
                    withAnimation(Self.bouncy) {
                        store.current = option
                        isExpanded = false
                    }
                } label: {
                    ZStack {
                        dotFill(for: option, palette: palette)
                        if isActive {
                            Circle()
                                .stroke(theme.foreground.opacity(0.9), lineWidth: 1.5)
                                .padding(-2.5)
                        }
                    }
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .scaleEffect(show ? 1 : 0.01)
                    .opacity(show ? 1 : 0)
                }
                .buttonStyle(.plain)
                .frame(width: show ? Self.dotSize : 0)
                .clipped()
                .help(option.label)
            }
        }
        .padding(.horizontal, isExpanded ? 9 : 6)
        .padding(.vertical, 5)
        .background(Capsule().fill(theme.card))
        .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
        .animation(Self.bouncy, value: isExpanded)
        .onHover { hovering in
            withAnimation(Self.bouncy) {
                isExpanded = hovering
            }
        }
    }

    /// Picks the right fill for a theme dot. System renders as a split
    /// black/white disc so users recognize it as "auto-adapt".
    @ViewBuilder
    private func dotFill(for option: AppTheme, palette: ThemePalette) -> some View {
        if option == .system {
            ZStack {
                Circle().fill(Color.white)
                Circle()
                    .fill(Color.black)
                    .mask(
                        Rectangle()
                            .frame(width: Self.dotSize, height: Self.dotSize)
                            .offset(x: Self.dotSize / 2)
                    )
            }
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.primary, palette.primaryDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}
