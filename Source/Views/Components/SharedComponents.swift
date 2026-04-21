//
//  SharedComponents.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Card

struct AppCard<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(theme.tertiary)
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
                .fill(theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        )
    }
}

extension AppCard where Trailing == EmptyView {
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, trailing: { EmptyView() }, content: content)
    }
}

extension AppCard {
    init(_ title: String,
         @ViewBuilder trailing: @escaping () -> Trailing,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, trailing: trailing, content: content)
    }
}

// MARK: - Row with label + description + trailing control

struct AppSettingRow<Trailing: View>: View {
    let title: String
    let description: String?
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.theme) private var theme

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
                    .foregroundStyle(theme.foreground)
                if let description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.muted)
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
    @Environment(\.theme) private var theme
    var body: some View {
        Rectangle()
            .fill(theme.dividerSubtle)
            .frame(height: 1)
    }
}

// MARK: - Button roles for themed tinting

enum AppButtonTint {
    case foreground, primary, destructive
}

// MARK: - Secondary (bordered) button

struct AppSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: AppButtonTint = .foreground
    let action: () -> Void

    @Environment(\.theme) private var theme
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
            .foregroundStyle(tintColor)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(isHovered ? theme.cardElevated : theme.cardInset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var tintColor: Color {
        switch tint {
        case .foreground:  return theme.foreground
        case .primary:     return theme.primary
        case .destructive: return theme.destructive
        }
    }

    private var borderColor: Color {
        switch tint {
        case .destructive: return theme.destructive.opacity(0.35)
        default:           return theme.borderStrong
        }
    }
}

// MARK: - Icon-only button

struct AppIconButton: View {
    let systemName: String
    var help: String = ""
    var tint: AppButtonTint = .foreground
    var spinOnTap: Bool = false
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false
    @State private var isSpinning = false

    var body: some View {
        Button(action: handleTap) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? theme.foreground : restingColor)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(isSpinning ? .easeInOut(duration: 0.6) : .default, value: isSpinning)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(isHovered ? theme.cardElevated : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }

    private var restingColor: Color {
        switch tint {
        case .foreground:  return theme.muted
        case .primary:     return theme.primary
        case .destructive: return theme.destructive
        }
    }

    private func handleTap() {
        if spinOnTap {
            isSpinning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isSpinning = false
            }
        }
        action()
    }
}

// MARK: - Provider choice card (welcome view)

struct AppProviderChoiceCard: View {
    let title: String
    let subtitle: String
    let assetName: String
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(theme.cardElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(theme.borderStrong, lineWidth: 1)
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
                            .fill(theme.cardElevated)
                        Circle()
                            .strokeBorder(theme.borderStrong, lineWidth: 1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.muted)
                    }
                    .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.muted)
                }

                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.success)
                    Text("Read-only access")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.muted)
                }
            }
            .padding(18)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .fill(isHovered ? theme.cardElevated : theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .strokeBorder(isHovered ? theme.borderFocus : theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Picker style

extension View {
    func appBoxedPicker(width: CGFloat = 200) -> some View {
        self
            .labelsHidden()
            .frame(width: width, alignment: .trailing)
    }
}
