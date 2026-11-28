//
//  SharePromptViews.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct PromoMessage {
    enum Action {
        case copyShareLink
        #if MAC_APP_STORE
        case openTipJar
        #endif
    }

    let title: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    let symbol: String
    let action: Action

    // Both placements use this order. Add new messages here and wire their action below.
    static let rotation: [Self] = {
        let messages: [Self] = [
            .init(title: "Share with friends", buttonTitle: "Copy link",
                  symbol: "square.and.arrow.up", action: .copyShareLink)
        ]
        #if MAC_APP_STORE
        return messages + [
            .init(title: "Like this app? Leave a tip.", buttonTitle: "Tip Jar",
                  symbol: "heart", action: .openTipJar)
        ]
        #else
        return messages
        #endif
    }()

    static func nextIndex(after index: Int) -> Int {
        (index + 1) % rotation.count
    }
}

struct PromoRow: View {
    static let dismissedVersionKey = "promoDismissedVersion"
    private static let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"

    let source: ShareSource
    // The popover supplies its opening's index; the sidebar advances in place.
    var menuIndex = 0
    var onOpenTipJar: () -> Void = {}

    @AppStorage(Self.dismissedVersionKey) private var dismissedVersion = ""
    @Environment(\.theme) private var theme
    @Environment(\.appearsActive) private var appearsActive
    private enum Control: Hashable { case action, dismiss }
    @FocusState private var focusedControl: Control?
    @AccessibilityFocusState private var accessibilityFocus: Control?
    @State private var isHovered = false
    @State private var isCopied = false
    @State private var sidebarIndex = 0

    private var isMenu: Bool { source == .menu }
    private var message: PromoMessage { PromoMessage.rotation[isMenu ? menuIndex : sidebarIndex] }
    private var pausesRotation: Bool {
        isMenu || !appearsActive || isHovered || isCopied || focusedControl != nil || accessibilityFocus != nil
    }
    private var tint: Color { isCopied ? theme.success : theme.primary }
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: AppRadius.md) }

    var body: some View {
        if dismissedVersion != Self.installedVersion {
            row
                .padding(.horizontal, isMenu ? 0 : 12)
                .padding(.top, isMenu ? 0 : 6)
                .padding(.bottom, isMenu ? 0 : 12)
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            Image(systemName: isCopied ? "checkmark" : message.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)

            Text(isCopied ? "Share link copied!" : message.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: isMenu ? 24 : 28, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: activate) {
                Text(isCopied ? "Copied" : message.buttonTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 24)
                    .background(tint.opacity(0.10), in: Capsule())
                    .overlay(Capsule().strokeBorder(tint.opacity(focusedControl == .action ? 1 : 0.35)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .focused($focusedControl, equals: .action)
            .accessibilityFocused($accessibilityFocus, equals: .action)

            Button {
                dismissedVersion = Self.installedVersion
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.muted)
                    .frame(width: 24, height: 24)
                    .background(theme.cardElevated, in: Circle())
                    .overlay(Circle().strokeBorder(focusedControl == .dismiss ? theme.primary : theme.border))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focused($focusedControl, equals: .dismiss)
            .accessibilityFocused($accessibilityFocus, equals: .dismiss)
            .help("Hide promos until the next app version")
            .accessibilityLabel("Hide promos until the next app version")
        }
        .padding(.horizontal, isMenu ? 14 : 10)
        .padding(.vertical, isMenu ? 7 : 8)
        .background {
            if isMenu {
                theme.primary.opacity(theme.isDark ? 0.10 : 0.06)
                    .overlay(alignment: .top) { theme.divider.frame(height: 1) }
            } else {
                cardShape.fill(theme.cardInset)
                    .overlay(cardShape.strokeBorder(theme.border))
            }
        }
        .onHover { isHovered = $0 }
        .onChange(of: menuIndex) { _, _ in isCopied = false }
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .seconds(1.8))
            if !Task.isCancelled { isCopied = false }
        }
        .task(id: pausesRotation) {
            guard !pausesRotation, PromoMessage.rotation.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(12))
                guard !Task.isCancelled, !pausesRotation else { return }
                sidebarIndex = PromoMessage.nextIndex(after: sidebarIndex)
            }
        }
    }

    private func activate() {
        switch message.action {
        case .copyShareLink:
            SharePromptStore().copyLink(from: source)
            isCopied = true
        #if MAC_APP_STORE
        case .openTipJar:
            onOpenTipJar()
        #endif
        }
    }
}
