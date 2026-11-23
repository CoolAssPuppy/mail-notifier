//
//  MicrosoftIDToken.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

/// Microsoft Entra tenants Mail Notifier needs to tell apart.
enum MicrosoftTenant {
    /// Every personal Microsoft account (Outlook.com, Hotmail, Live) signs in
    /// through this one tenant. Any other tenant is an organization.
    static let consumerTenantID = "9188040d-6c67-4c5b-b112-36a304b66dad"

    static func isWorkOrSchool(tenantID: String) -> Bool {
        tenantID.lowercased() != consumerTenantID
    }
}

/// The claims Mail Notifier reads from a Microsoft ID token. The token is not
/// verified here: it came straight from Microsoft's token endpoint over TLS in
/// the same exchange, and nothing here grants access to anything.
struct MicrosoftIDToken {
    /// Lowercased `email`, then `preferred_username`, then `upn`.
    let email: String?
    /// `tid`, or the tenant segment of `iss` when `tid` is missing.
    let tenantID: String?

    /// Nil when the tenant is unknown.
    var isWorkOrSchool: Bool? {
        tenantID.map { MicrosoftTenant.isWorkOrSchool(tenantID: $0) }
    }

    init?(jwt: String) {
        guard let claims = Self.decodeClaims(jwt) else { return nil }

        func claim(_ key: String) -> String? {
            guard let value = claims[key] as? String, !value.isEmpty else { return nil }
            return value
        }

        email = (claim("email") ?? claim("preferred_username") ?? claim("upn"))?.lowercased()
        tenantID = claim("tid") ?? claim("iss").flatMap(Self.tenant(fromIssuer:))
    }

    /// `https://login.microsoftonline.com/{tid}/v2.0` gives `{tid}`.
    private static func tenant(fromIssuer issuer: String) -> String? {
        guard let url = URL(string: issuer) else { return nil }
        let segments = url.path.split(separator: "/").map(String.init)
        guard let first = segments.first, UUID(uuidString: first) != nil else { return nil }
        return first
    }

    private static func decodeClaims(_ jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }
        var base64 = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64.append(String(repeating: "=", count: (4 - base64.count % 4) % 4))

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}
