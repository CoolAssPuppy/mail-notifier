//
//  SharePromptViews.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Copy

enum SharePromptCopy {
    static let ask = NSLocalizedString("Help us grow.", comment: "Share prompt, first sentence")
    static let share = NSLocalizedString("Share Mail Notifier.", comment: "Share prompt, second sentence")
    static let copied = NSLocalizedString("Share link copied!", comment: "Share prompt after the link is copied")
    static let copyLink = NSLocalizedString("Copy link", comment: "Button that copies the Mail Notifier web page link")
    static let copiedButton = NSLocalizedString("Copied", comment: "Copy link button just after copying")
    static let close = NSLocalizedString("Close", comment: "Closes the share drawer")
}

// MARK: - Copied state

/// Copies the link and holds the "copied" look for a moment.
@MainActor
final class ShareLinkCopier: ObservableObject {
    @Published private(set) var isShowingCopied: Bool
    private var resetTask: Task<Void, Never>?
    private let store: SharePromptStore

    init(store: SharePromptStore = SharePromptStore(), isShowingCopied: Bool = false) {
        self.store = store
        self.isShowingCopied = isShowingCopied
    }

    /// Copies, shows the confirmation, then calls `afterConfirmation`.
    func copy(from source: ShareSource, afterConfirmation: (() -> Void)? = nil) {
        store.copyLink(from: source)
        isShowingCopied = true
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            if let afterConfirmation {
                afterConfirmation()
            } else {
                self?.isShowingCopied = false
            }
        }
    }
}

// MARK: - Pieces

/// "Help us grow. Share Mail Notifier." or, just after copying, the
/// confirmation in the success color.
private struct ShareMessage: View {
    let isShowingCopied: Bool
    var stacked = false
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if isShowingCopied {
                Label {
                    Text(SharePromptCopy.copied)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.success)
                .transition(.opacity.combined(with: .offset(y: 3)))
            } else if stacked {
                VStack(alignment: .leading, spacing: 1) {
                    Text(SharePromptCopy.ask)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                    Text(SharePromptCopy.share)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.muted)
                }
                .transition(.opacity)
            } else {
                (Text(SharePromptCopy.ask).foregroundColor(theme.foreground).fontWeight(.semibold)
                 + Text(" ")
                 + Text(SharePromptCopy.share).foregroundColor(theme.muted))
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The pill that copies the link. It turns into a check while the
/// confirmation shows.
private struct CopyLinkButton: View {
    let isShowingCopied: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isShowingCopied ? "checkmark" : "link")
                    .font(.system(size: 10, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(isShowingCopied ? SharePromptCopy.copiedButton : SharePromptCopy.copyLink)
                    .font(.system(size: 10, weight: .semibold))
            }
            .fixedSize()
            .foregroundStyle(isShowingCopied ? theme.success : theme.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(isHovered ? 0.2 : 0.12)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .fixedSize()
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(SharePromptStore.shareURL.absoluteString)
        .accessibilityLabel(isShowingCopied ? SharePromptCopy.copied : SharePromptCopy.copyLink)
    }

    private var tint: Color { isShowingCopied ? theme.success : theme.primary }
}

// MARK: - Popover drawer

/// A tray under the popover's bottom bar. Its content drops in just after the
/// popover opens; copying shows the confirmation and then closes the tray.
struct SharePromptDrawer: View {
    @StateObject private var copier: ShareLinkCopier
    let onRetire: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isContentShown: Bool

    init(isShowingCopied: Bool = false, startsOpen: Bool = false, onRetire: @escaping () -> Void) {
        _copier = StateObject(wrappedValue: ShareLinkCopier(isShowingCopied: isShowingCopied))
        _isContentShown = State(initialValue: startsOpen)
        self.onRetire = onRetire
    }

    var body: some View {
        HStack(spacing: 8) {
            ShareMessage(isShowingCopied: copier.isShowingCopied)
            Spacer(minLength: 6)
            CopyLinkButton(isShowingCopied: copier.isShowingCopied) {
                withAnimation(.easeOut(duration: 0.2)) {
                    copier.copy(from: .menu) { onRetire() }
                }
            }
            Button {
                SharePromptStore().dismissDrawer()
                onRetire()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.tertiary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(SharePromptCopy.close)
            .accessibilityLabel(SharePromptCopy.close)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .opacity(isContentShown ? 1 : 0)
        .offset(y: isContentShown ? 0 : -6)
        .frame(maxWidth: .infinity)
        .background(theme.primary.opacity(theme.isDark ? 0.10 : 0.06))
        .overlay(Rectangle().fill(theme.divider).frame(height: 1), alignment: .top)
        .clipped()
        .task {
            guard !isContentShown else { return }
            if reduceMotion {
                isContentShown = true
                return
            }
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                isContentShown = true
            }
        }
    }
}

// MARK: - Main window box

/// The inset dashed box under the account list in the main window.
struct SharePromptBox: View {
    @StateObject private var copier: ShareLinkCopier
    @Environment(\.theme) private var theme

    init(isShowingCopied: Bool = false) {
        _copier = StateObject(wrappedValue: ShareLinkCopier(isShowingCopied: isShowingCopied))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ShareMessage(isShowingCopied: copier.isShowingCopied, stacked: true)
                .frame(minHeight: 28, alignment: .leading)
            Spacer(minLength: 4)
            CopyLinkButton(isShowingCopied: copier.isShowingCopied) {
                withAnimation(.easeOut(duration: 0.2)) {
                    copier.copy(from: .settings)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: copier.isShowingCopied)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(theme.cardInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(theme.borderStrong)
        )
    }
}
