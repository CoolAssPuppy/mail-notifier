//
//  PolarLicenseClient.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Polar (polar.sh) license-key client. The customer-portal license-key
//  endpoints take no auth — the key plus the public organization id are the
//  whole request — so entitlement works with no server of ours. Stateless and
//  Sendable; `EntitlementManager` owns persistence of the key and activation id.
//
//  All parsing lives in static helpers so it unit-tests against fixture JSON
//  with no network.
//

import Foundation

struct PolarLicenseClient: LicenseProvider {
    private let organizationId: String
    private let benefitId: String
    private let session: URLSession
    private let baseURL: URL

    init(organizationId: String = PolarConfig.organizationId,
         benefitId: String = PolarConfig.benefitId,
         session: URLSession = .shared,
         baseURL: URL = PolarConfig.apiBaseURL) {
        self.organizationId = organizationId
        self.benefitId = benefitId
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: LicenseProvider

    func activate(key: String, deviceLabel: String) async throws -> LicenseActivation {
        let data = try await post(path: "v1/customer-portal/license-keys/activate", body: [
            "key": key,
            "organization_id": organizationId,
            "label": deviceLabel
        ])
        let activation = try Self.decodeActivation(data)
        try Self.checkBenefit(activation.status, expected: benefitId)
        return activation
    }

    func validate(key: String, activationId: String?) async throws -> LicenseStatus {
        var body = ["key": key, "organization_id": organizationId]
        if let activationId { body["activation_id"] = activationId }
        let data = try await post(path: "v1/customer-portal/license-keys/validate", body: body)
        let status = try Self.decodeStatus(data)
        try Self.checkBenefit(status, expected: benefitId)
        return status
    }

    func deactivate(key: String, activationId: String) async throws {
        _ = try await post(path: "v1/customer-portal/license-keys/deactivate", body: [
            "key": key,
            "organization_id": organizationId,
            "activation_id": activationId
        ])
    }

    // MARK: Networking

    private func post(path: String, body: [String: String]) async throws -> Data {
        guard !organizationId.isEmpty else { throw LicenseError.notConfigured }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response, data: data)
        return data
    }

    // MARK: Pure logic (unit-tested)

    /// Maps an HTTP status to a semantic error, leaving 2xx to the parser. 404
    /// is an unknown key. An activation-limit rejection is called out by name so
    /// the paywall can say something useful; Mail Notifier's benefit sets no
    /// limit, but a future change in the Polar dashboard shouldn't produce a
    /// baffling error here.
    static func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300:
            return
        case 404:
            throw LicenseError.invalidKey
        case 403, 422:
            let message = errorMessage(data)
            let lower = message.lowercased()
            if lower.contains("activation") && lower.contains("limit") {
                throw LicenseError.activationLimitReached
            }
            throw LicenseError.requestFailed(status: http.statusCode, message: message)
        default:
            throw LicenseError.requestFailed(status: http.statusCode, message: errorMessage(data))
        }
    }

    /// Rejects a key issued against a different benefit.
    ///
    /// Mail Notifier shares the Strategic Nerds Polar organization with the other
    /// apps, and Polar's validate endpoint grants on organization membership
    /// alone: without this check, a Sync Bar subscriber's key unlocks Mail
    /// Notifier. So `POLAR_BENEFIT_ID` is required in any shipped build, not
    /// optional. `PolarConfig.isBenefitPinMissing` is what notices when it isn't.
    ///
    /// Two deliberate fail-open paths, both logged:
    ///
    /// - No benefit configured. A fork or dev build, which has no paywall anyway.
    /// - The response omitted `benefit_id`. If Polar ever stops sending the
    ///   field, failing closed would lock out every paying customer on the same
    ///   day, while failing open costs at most a subscriber to another Strategic
    ///   Nerds app getting this one thrown in.
    static func checkBenefit(_ status: LicenseStatus, expected: String) throws {
        guard !expected.isEmpty else { return }
        guard let actual = status.benefitId, !actual.isEmpty else {
            Log.license.error("Polar returned a license key with no benefit_id, so the product pin could not be checked. Accepting the key; keys for other Strategic Nerds products would also pass right now.")
            return
        }
        guard actual == expected else { throw LicenseError.wrongProduct }
    }

    /// Decodes a validate response: the license key object at the top level.
    static func decodeStatus(_ data: Data) throws -> LicenseStatus {
        guard let payload = try? JSONDecoder().decode(KeyPayload.self, from: data) else {
            throw LicenseError.invalidResponse("Couldn't read Polar's response.")
        }
        return status(from: payload)
    }

    /// Decodes an activate response: the activation `id` plus the nested
    /// `license_key` status, falling back to a top-level key shape.
    static func decodeActivation(_ data: Data) throws -> LicenseActivation {
        guard let envelope = try? JSONDecoder().decode(ActivationPayload.self, from: data) else {
            throw LicenseError.invalidResponse("Couldn't read the activation from Polar's response.")
        }
        let keyPayload = envelope.license_key
            ?? (try? JSONDecoder().decode(KeyPayload.self, from: data))
            ?? KeyPayload()
        return LicenseActivation(activationId: envelope.id, status: status(from: keyPayload))
    }

    static func status(from payload: KeyPayload) -> LicenseStatus {
        LicenseStatus(
            state: LicenseStatus.State(rawValue: payload.status ?? "") ?? .unknown,
            expiresAt: payload.expires_at.flatMap(Formatters.parseISO8601),
            customerId: payload.customer_id ?? payload.customer?.id,
            benefitId: payload.benefit_id
        )
    }

    /// Best-effort extraction of a human message from a Polar error body
    /// (`{detail}`, `{error}`, or FastAPI's `{detail: [{msg}]}`).
    static func errorMessage(_ data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let text = String(data: data, encoding: .utf8) ?? ""
            return text.isEmpty ? "Unknown error" : String(text.prefix(200))
        }
        if let detail = object["detail"] as? String { return detail }
        if let error = object["error"] as? String { return error }
        if let list = object["detail"] as? [[String: Any]], let msg = list.first?["msg"] as? String { return msg }
        return "Unknown error"
    }

    // Decoding shapes mirroring Polar's license-key payloads. Snake case is kept
    // verbatim rather than run through a key-decoding strategy so the wire
    // format is readable straight from the struct.
    struct KeyPayload: Decodable {
        var status: String?
        var expires_at: String?
        var benefit_id: String?
        var customer_id: String?
        var customer: CustomerPayload?
    }

    struct CustomerPayload: Decodable {
        var id: String?
    }

    private struct ActivationPayload: Decodable {
        let id: String
        let license_key: KeyPayload?
    }
}
