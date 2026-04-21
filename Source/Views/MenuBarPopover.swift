//
//  MenuBarPopover.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - Color Tokens

private extension Color {
    static let popBackground   = Color(red: 0x0E/255, green: 0x11/255, blue: 0x17/255)
    static let popHeaderBg     = Color(red: 0x10/255, green: 0x13/255, blue: 0x1A/255)
    static let popCard         = Color(red: 0x13/255, green: 0x17/255, blue: 0x1F/255)
    static let popCardElevated = Color(red: 0x1A/255, green: 0x1F/255, blue: 0x29/255)
    static let popBorder       = Color(red: 0x1F/255, green: 0x24/255, blue: 0x2E/255)
    static let popBorderStrong = Color(red: 0x26/255, green: 0x2C/255, blue: 0x38/255)
    static let popDivider      = Color(red: 0x1D/255, green: 0x21/255, blue: 0x29/255)
    static let popForeground   = Color(red: 0xEC/255, green: 0xEF/255, blue: 0xF4/255)
    static let popMuted        = Color(red: 0x8A/255, green: 0x8F/255, blue: 0x9A/255)
    static let popTertiary     = Color(red: 0x6B/255, green: 0x70/255, blue: 0x80/255)
    static let popPrimary      = Color(red: 0x4F/255, green: 0x8A/255, blue: 0xFF/255)
    static let popSuccess      = Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)
    static let popWarning      = Color(red: 0xFB/255, green: 0xBF/255, blue: 0x24/255)
    static let popDestructive  = Color(red: 0xF8/255, green: 0x71/255, blue: 0x71/255)
}

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

    private let fetcherManager = FetcherManager.shared
    private var subscriptions = Set<AnyCancellable>()
    private static let recentMessageLimit = 3

    init() {
        refresh()
        subscribe()
    }

    func refresh() {
        let accounts = Array(Accounts.default)
        accountStates = accounts.map { account in
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
        totalUnread = accountStates.reduce(0) { $0 + $1.unreadCount }
        lastCheckedAt = accountStates.compactMap(\.lastCheckedAt).max()
    }

    private func subscribe() {
        let names: [Notification.Name] = [
            .accountAdded, .accountDeleted, .accountUpdated, .accountsReordered,
            .messagesFetched, .unreadCountUpdated
        ]
        for name in names {
            NotificationCenter.default
                .publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.refresh() }
                .store(in: &subscriptions)
        }
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
            Divider().background(Color.popDivider)
            content
            Divider().background(Color.popDivider)
            BottomBar(actions: actions)
        }
        .frame(width: 380)
        .background(Color.popBackground)
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
                    .foregroundStyle(Color.popForeground)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.popSuccess)
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.popSuccess.opacity(0.5), radius: 4)
                    Text(statusLine)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.popMuted)
                }
            }

            Spacer(minLength: 8)

            if totalUnread > 0 {
                UnreadPill(count: totalUnread)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.popHeaderBg)
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
                        colors: [Color(red: 0x4F/255, green: 0x8A/255, blue: 0xFF/255),
                                 Color(red: 0x25/255, green: 0x63/255, blue: 0xEB/255)],
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
                .foregroundStyle(Color.popWarning)
            Text("\(count) unread")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.popWarning)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.popWarning.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(Color.popWarning.opacity(0.3), lineWidth: 1)
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
                .foregroundStyle(Color.popTertiary)
            Spacer()
            if let timestamp = lastCheckedAt {
                Text("Last checked \(timestamp, formatter: Self.timeFormatter)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.popTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

// MARK: - Account Card

private struct AccountCard: View {
    let state: MenuBarPopoverModel.AccountState
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
                Divider().background(Color.popBorder)
                messagesList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.popCard)
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
            return Color.popDestructive.opacity(0.25)
        } else if isExpanded {
            return Color(red: 0x2D/255, green: 0x39/255, blue: 0x56/255)
        } else {
            return Color.popBorder
        }
    }

    private var headerRow: some View {
        Button(action: handleHeaderTap) {
            HStack(spacing: 10) {
                ProviderBadge(type: state.account.type, dimmed: state.hasAuthError)

                VStack(alignment: .leading, spacing: 1) {
                    Text(state.account.email)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.popForeground)
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
                    .foregroundStyle(Color.popDestructive)
                Text("Authorization expired")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.popDestructive)
            }
        } else {
            Text(secondaryLine)
                .font(.system(size: 10))
                .foregroundStyle(Color.popMuted)
                .lineLimit(1)
        }
    }

    private var secondaryLine: String {
        let typeLabel = state.account.type == .gmail ? "Gmail" : "Outlook"
        if let timestamp = state.lastCheckedAt {
            return "\(typeLabel) · checked \(Self.timeFormatter.string(from: timestamp))"
        }
        return typeLabel
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if state.hasAuthError {
            Button(action: onReauthorize) {
                Text("Reauthorize")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.popDestructive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.popDestructive.opacity(0.12))
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.popDestructive.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 6) {
                if state.unreadCount > 0 {
                    Text("\(state.unreadCount) new")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.popWarning)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.popWarning.opacity(0.12))
                        )
                        .overlay(
                            Capsule().strokeBorder(Color.popWarning.opacity(0.3), lineWidth: 1)
                        )
                }

                if canExpand {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.popTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeOut(duration: 0.18), value: isExpanded)
                }
            }
        }
    }

    @ViewBuilder
    private var headerBackground: some View {
        if isExpanded && canExpand {
            Color.popPrimary.opacity(0.06)
        } else if isHovered {
            Color.white.opacity(0.02)
        } else {
            Color.clear
        }
    }

    private var messagesList: some View {
        VStack(spacing: 1) {
            ForEach(state.recentMessages, id: \.id) { message in
                MessageRow(message: message) {
                    onOpenMessage(message)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func handleHeaderTap() {
        if state.hasAuthError {
            return
        }
        if canExpand {
            isExpanded.toggle()
        } else {
            // No messages yet — open inbox in browser instead.
            onOpenInbox()
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

// MARK: - Provider Badge

private struct ProviderBadge: View {
    let type: AccountType
    let dimmed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.popCardElevated)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.popBorderStrong, lineWidth: 1)
            Text(letter)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(letterColor.opacity(dimmed ? 0.4 : 1))
        }
        .frame(width: 24, height: 24)
    }

    private var letter: String {
        switch type {
        case .gmail: return "M"
        case .outlook: return "O"
        }
    }

    private var letterColor: Color {
        switch type {
        case .gmail: return Color(red: 0xEA/255, green: 0x43/255, blue: 0x35/255)
        case .outlook: return Color(red: 0x00/255, green: 0x78/255, blue: 0xD4/255)
        }
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: Message
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    if isVIP {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.popWarning)
                    }
                    Text(message.sender)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.popForeground)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(timeString)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.popTertiary)
                        .monospacedDigit()
                }
                Text(snippetLine)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.popMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.popPrimary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var isVIP: Bool {
        let vipList = VIPList(rawValue: UserDefaults.standard.string(forKey: VIPList.storageKey) ?? "[]") ?? []
        return vipList.contains(where: { $0.email.lowercased() == message.senderEmail })
    }

    private var snippetLine: String {
        let subject = message.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        if !subject.isEmpty { return subject }
        return message.decodedSnippet
    }

    private var timeString: String {
        let calendar = Calendar.current
        let now = Date()
        let date = message.serverDate
        if calendar.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            return Self.weekdayFormatter.string(from: date)
        } else {
            return Self.shortDateFormatter.string(from: date)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

// MARK: - Empty State

private struct EmptyAccountsState: View {
    let onAddAccount: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.popCard)
                Image(systemName: "envelope")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color.popMuted)
            }
            .frame(width: 56, height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.popBorder, lineWidth: 1)
            )

            VStack(spacing: 4) {
                Text("No accounts yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.popForeground)
                Text("Add a Gmail or Outlook inbox to start watching your mail.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.popMuted)
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
                .foregroundStyle(Color.popPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.popPrimary.opacity(0.12))
                )
                .overlay(
                    Capsule().strokeBorder(Color.popPrimary.opacity(0.3), lineWidth: 1)
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
            CheckNowIconButton(action: actions.checkAll)
            IconButton(systemName: "macwindow", help: "Open main window", action: actions.openWindow)
            IconButton(systemName: "gearshape", help: "Settings (⌘,)", action: actions.openSettings)

            Spacer(minLength: 0)

            IconButton(systemName: "power", help: "Quit Mail Notifier", action: actions.quit)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.popHeaderBg)
    }
}

private struct CheckNowIconButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @State private var isSpinning = false

    var body: some View {
        Button(action: {
            isSpinning = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isSpinning = false
            }
        }) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? Color.popForeground : Color.popMuted)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(isSpinning ? .easeInOut(duration: 0.6) : .default, value: isSpinning)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.popCardElevated : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Check all accounts now")
    }
}

private struct IconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? Color.popForeground : Color.popMuted)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.popCardElevated : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}
