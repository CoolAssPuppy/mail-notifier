//
//  WhyChargeDisclosure.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  The "Why charge?" link and the answer it folds out. Shared by the paywall
//  sheet and the Settings subscription card so the two can't drift apart, since
//  the whole point of `PaywallCopy` is that the pitch is written once.
//

import SwiftUI

struct WhyChargeDisclosure: View {
    /// The paywall sheet already prints the short explanation above this, so it
    /// asks for the blunt half alone. Settings has no room for the long version,
    /// so it shows both.
    var includesShortExplanation: Bool = false

    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 4) {
                    Text(PaywallCopy.whyChargeLabel)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(theme.primary)
            }
            .buttonStyle(.plain)

            if isExpanded { answer }
        }
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if includesShortExplanation {
                Text(PaywallCopy.whyItCosts)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(PaywallCopy.whyChargeBody)
                .font(.system(size: 11))
                .foregroundStyle(theme.foregroundSoft)
                .fixedSize(horizontal: false, vertical: true)

            // Absent until a confirmed address is filled in, so the app never
            // points anyone at a guessed mailbox.
            if let action = PaywallCopy.whyChargeAction {
                Text(action)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.foregroundSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(theme.cardInset)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

#Preview {
    WhyChargeDisclosure(includesShortExplanation: true)
        .frame(width: 380)
        .padding()
}
