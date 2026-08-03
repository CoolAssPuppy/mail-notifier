//
//  PaywallSheet.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  The subscription gate, shown when someone tries to connect a second inbox or
//  clicks an account the subscription has paused.
//
//  Title, two paragraphs, one button. The X in the corner is the only way out,
//  because a second dismiss button is one more thing to read. The license paste
//  field stays folded away: it exists for the few people who already paid.
//
//  No copy lives in this file. Every string comes from `PaywallCopy`.
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
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section(PaywallCopy.whyPayTitle, PaywallCopy.whyPayBody)
                    section(PaywallCopy.namePriceTitle, PaywallCopy.namePriceBody)

                    if isEntitled {
                        activeNote
                    } else {
                        subscribeSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 420, height: 440)
        .background(theme.background)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(PaywallCopy.sheetTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text(PaywallCopy.sheetSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            AppIconButton(systemName: "xmark", help: "Close", action: onClose)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 22)
    }

    // MARK: Sections

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.foreground)
            Text(body)
                .font(.system(size: 12))
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
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
