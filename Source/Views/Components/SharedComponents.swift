//
//  SharedComponents.swift
//  Mail Notifier
//
//  Reusable SwiftUI building blocks for the redesigned app: cards, rows,
//  toggles, primary/secondary buttons.
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Card

/// Section card with uppercase label, optional trailing accessory, and body content.
struct AppCard<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.appTertiary)
                Spacer(minLength: 0)
                trailing()
            }
            .padding(.bottom, AppSpacing.lg)

            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(Color.appCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 1)
        )
    }
}

extension AppCard where Trailing == EmptyView {
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = { EmptyView() }
        self.content = content
    }
}

extension AppCard {
    init(_ title: String,
         @ViewBuilder trailing: @escaping () -> Trailing,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }
}

// MARK: - Row with label + description + trailing control

struct AppSettingRow<Trailing: View>: View {
    let title: String
    let description: String?
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String,
         description: String? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.description = description
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.appForeground)
                if let description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: AppSpacing.md)
            trailing()
        }
    }
}

// MARK: - Row divider

struct AppRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.appDividerSubtle)
            .frame(height: 1)
    }
}

// MARK: - Secondary (bordered) button

struct AppSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .appForeground
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(isHovered ? Color.appCardElevated : Color.appCardInset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var borderColor: Color {
        tint == .appDestructive
            ? Color.appDestructive.opacity(0.35)
            : Color.appBorderStrong
    }
}

// MARK: - Icon-only button

struct AppIconButton: View {
    let systemName: String
    var help: String = ""
    var tint: Color = .appMuted
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? Color.appForeground : tint)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(isHovered ? Color.appCardElevated : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

// MARK: - Provider choice card (welcome view)

struct AppProviderChoiceCard: View {
    let title: String
    let subtitle: String
    let assetName: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.appCardElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(Color.appBorderStrong, lineWidth: 1)
                            )
                        Image(assetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                    }
                    .frame(width: 36, height: 36)

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.appCardElevated)
                        Circle()
                            .strokeBorder(Color.appBorderStrong, lineWidth: 1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.appMuted)
                    }
                    .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appForeground)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                }

                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.appSuccess)
                    Text("Read-only access")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appMuted)
                }
            }
            .padding(18)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .fill(isHovered ? Color.appCardElevated : Color.appCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .strokeBorder(isHovered ? Color.appBorderFocus : Color.appBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Legacy section header kept for compile compatibility with old previews.

struct SectionHeader: View {
    let icon: String
    let title: String
    let gradient: [Color]

    var body: some View {
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
