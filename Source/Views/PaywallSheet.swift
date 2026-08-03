//
//  PaywallSheet.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  The subscription gate, shown when someone tries to connect a second inbox or
//  clicks an account the subscription has paused. Two paths out: subscribe in
//  the browser, or paste a key you already have.
//
//  No copy lives in this file. Every string comes from `PaywallCopy`, so the
//  pitch can be rewritten without reading any SwiftUI.
//

import SwiftUI
import AppKit

struct PaywallSheet: View {
    let trigger: PaywallTrigger
    let onClose: () -> Void

    @ObservedObject private var entitlement = EntitlementManager.shared
    @Environment(\.theme) private var theme

    @State private var licenseKey = ""
    @State private var activating = false
    @State private var errorMessage: String?
    @State private var showingKeyField = false

    private var isEntitled: Bool { entitlement.isEntitled }

    var body: some View {
        VStack(spacing: 0) {
            header
            AppRowDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    priceCard
                    whyCard
                    if isEntitled {
                        activeNote
                    } else {
                        subscribeSection
                    }
                    termsText
                }
                .padding(20)
            }

            AppRowDivider()
            footer
        }
        .frame(width: 480, height: 540)
        .background(theme.background)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(PaywallCopy.sheetTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(trigger.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.muted)
            }
            Spacer(minLength: 12)
            AppIconButton(systemName: "xmark", help: "Close", action: onClose)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: Cards

    private var priceCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 17))
                .foregroundStyle(theme.primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(theme.primary.opacity(0.10))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(PaywallCopy.priceDetail)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(PaywallCopy.terms)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        )
    }

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why this costs money")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.foregroundSoft)
            Text(PaywallCopy.whyItCosts)
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            // The short explanation is already printed above, so the link only
            // needs to add the blunt half.
            WhyChargeDisclosure()
        }
    }

    private var activeNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13))
                .foregroundStyle(theme.success)
            Text(PaywallCopy.activeNote)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.foregroundSoft)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var subscribeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppPrimaryButton(title: LocalizedStringKey(PaywallCopy.subscribeButton),
                             systemImage: "arrow.up.forward.app",
                             isDisabled: PolarConfig.checkoutURL == nil,
                             fillsWidth: true) {
                subscribe()
            }

            if PolarConfig.checkoutURL == nil {
                Text(PaywallCopy.notConfiguredNote)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.warning)
            }

            // The paste field is for the few people who already paid, so it
            // stays folded away until asked for.
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showingKeyField.toggle() } }) {
                HStack(spacing: 4) {
                    Text(PaywallCopy.hasKeyPrompt)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: showingKeyField ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(theme.primary)
            }
            .buttonStyle(.plain)

            if showingKeyField { keyField }
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PaywallCopy.keyLocationHint)
                .font(.system(size: 10))
                .foregroundStyle(theme.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(PaywallCopy.keyFieldPlaceholder, text: $licenseKey)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(theme.cardInset)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(theme.borderStrong, lineWidth: 1)
                )
                .onSubmit(activate)

            HStack {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                AppPrimaryButton(title: activating ? "Activating…" : "Activate",
                                 isDisabled: trimmedKey.isEmpty || activating,
                                 action: activate)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var termsText: some View {
        Text(PaywallCopy.terms)
            .font(.system(size: 9.5))
            .foregroundStyle(theme.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if let portal = PolarConfig.portalURL, entitlement.hasStoredKey {
                Link(destination: portal) {
                    Text(PaywallCopy.manageButton)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            AppSecondaryButton(title: isEntitled ? "Done" : "Not now", action: onClose)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(theme.surface)
    }

    // MARK: Actions

    private var trimmedKey: String {
        licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func subscribe() {
        guard let url = PolarConfig.checkoutURL else { return }
        Telemetry.capture(.subscribeClicked, properties: ["trigger": trigger.rawValue])
        NSWorkspace.shared.open(url)
        // Checkout finishes in the browser and the key arrives by email, so open
        // the paste field now rather than making them find it on their return.
        withAnimation { showingKeyField = true }
    }

    private func activate() {
        let key = trimmedKey
        guard !key.isEmpty, !activating else { return }
        activating = true
        errorMessage = nil
        Task {
            do {
                try await entitlement.activate(key: key)
                activating = false
                licenseKey = ""
                Telemetry.capture(.licenseActivated)
            } catch {
                activating = false
                errorMessage = Formatters.userMessage(for: error)
                Telemetry.capture(.licenseActivationFailed,
                                  properties: ["reason": Self.failureReason(for: error)])
            }
        }
    }

    /// A coarse, non-identifying label for why an activation failed. The key
    /// itself never goes near telemetry.
    static func failureReason(for error: Error) -> String {
        switch error {
        case let licenseError as LicenseError:
            switch licenseError {
            case .notConfigured:           return "not_configured"
            case .invalidKey:              return "invalid_key"
            case .wrongProduct:            return "wrong_product"
            case .activationLimitReached:  return "activation_limit"
            case .requestFailed:           return "request_failed"
            case .invalidResponse:         return "invalid_response"
            }
        case is URLError:
            return "network"
        default:
            return "unknown"
        }
    }
}

#Preview {
    PaywallSheet(trigger: .addAccount, onClose: {})
}
