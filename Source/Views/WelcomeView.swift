//
//  WelcomeView.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 28) {
                heroBadge

                VStack(spacing: 10) {
                    Text("Welcome to Mail Notifier")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.appForeground)
                        .fixedSize()

                    Text("Connect a Gmail or Outlook inbox and Mail Notifier will quietly watch it from your menu bar. No mail data ever leaves your Mac.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    AppProviderChoiceCard(
                        title: "Gmail",
                        subtitle: "Personal or Workspace via OAuth",
                        assetName: "Gmail"
                    ) {
                        Accounts.authorize(type: .gmail)
                    }

                    AppProviderChoiceCard(
                        title: "Outlook",
                        subtitle: "Hotmail, Office 365 via Microsoft",
                        assetName: "Outlook"
                    ) {
                        Accounts.authorize(type: .outlook)
                    }
                }
                .padding(.top, 4)

                trustSignals
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private var heroBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appPrimary.opacity(0.18),
                            Color.appPrimaryDeep.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.appPrimary.opacity(0.25), lineWidth: 1)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.appPrimary, Color.appPrimaryDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(color: Color.appPrimary.opacity(0.35), radius: 16, y: 8)
                .overlay(
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
        .frame(width: 96, height: 96)
    }

    private var trustSignals: some View {
        HStack(spacing: 14) {
            trustItem(icon: "lock.fill", label: "Tokens stored in macOS Keychain")

            Circle()
                .fill(Color.appDim)
                .frame(width: 3, height: 3)

            trustItem(icon: "info.circle", label: "No telemetry, no analytics, no servers")
        }
    }

    private func trustItem(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.appTertiary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.appTertiary)
        }
    }
}

#Preview {
    WelcomeView()
        .frame(width: 820, height: 560)
}
