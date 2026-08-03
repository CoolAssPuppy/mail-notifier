//
//  LicenseProvider.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  The provider-neutral boundary for the paid multi-account subscription. The
//  concrete billing provider (Polar today) hides behind `LicenseProvider`, so
//  swapping it means writing one new conformer instead of editing every gate.
//  `LicenseStatus` is the normalized snapshot every provider maps its response
//  onto.
//

import Foundation

/// One device's license activation: the activation id to replay on validate and
/// deactivate, plus the status captured at activation time.
struct LicenseActivation: Equatable, Sendable {
    let activationId: String
    let status: LicenseStatus
}

/// A normalized, point-in-time license snapshot, provider-agnostic.
struct LicenseStatus: Equatable, Sendable {
    /// The provider's verdict. `granted` is the only entitled state; `revoked`
    /// and `disabled` are explicit lapses; `unknown` covers a value we don't
    /// recognize, which is treated as not entitled.
    enum State: String, Sendable {
        case granted, revoked, disabled, unknown
    }

    let state: State
    /// Paid-through date when the provider supplies one. Drives grace: a
    /// transient network failure never locks out a payer before this passes.
    /// `nil` when the license key carries no expiry, which is how Mail
    /// Notifier's benefit is configured — Polar revokes the key on cancellation
    /// instead, so revocation rather than expiry is the lapse signal.
    let expiresAt: Date?
    /// The provider's customer id. Kept so a support request can be tied to a
    /// Polar customer without asking the user for their key.
    let customerId: String?
    /// The benefit the key was issued against, checked against `PolarBenefitID`
    /// when that is configured. See `PolarLicenseClient` for why.
    let benefitId: String?

    var isGranted: Bool { state == .granted }
}

/// Provider-neutral license operations. Network failures arrive as the
/// underlying `URLError`, which the caller reads as "couldn't reach the server"
/// and answers with grace. Semantic failures (bad key, wrong product) arrive as
/// `LicenseError`.
protocol LicenseProvider: Sendable {
    /// Activates the key on this device, returning the activation to persist.
    func activate(key: String, deviceLabel: String) async throws -> LicenseActivation
    /// Re-checks the key (optionally pinned to an activation), returning fresh status.
    func validate(key: String, activationId: String?) async throws -> LicenseStatus
    /// Releases this device's activation, when removing the license locally.
    func deactivate(key: String, activationId: String) async throws
}

/// Semantic (non-network) failures from a license operation.
enum LicenseError: LocalizedError, Equatable, Sendable {
    case notConfigured
    case invalidKey
    case wrongProduct
    case activationLimitReached
    case requestFailed(status: Int, message: String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Subscriptions aren't available in this build yet."
        case .invalidKey:
            return "That license key wasn't recognized. Check it and try again."
        case .wrongProduct:
            return "That license key is for a different product."
        case .activationLimitReached:
            return "This license is already active on the maximum number of devices. Remove it from one first."
        case .requestFailed(let status, let message):
            return "Couldn't reach the subscription service (HTTP \(status)): \(message)"
        case .invalidResponse(let message):
            return message
        }
    }
}
