//
//  SigninFailure.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation
import AppAuth

/// A sign-in that did not produce an account, sorted by what the person can
/// do about it.
///
/// Analytics get the error's domain, code and OAuth `error` string. The
/// `error_description` is read on the device to recognise an admin consent
/// block and never leaves it, because Microsoft puts account names and tenant
/// names in it.
struct SigninFailure: Identifiable {
    enum Kind: String {
        /// The person's organization has to approve the app first.
        case adminConsentRequired = "admin_consent_required"
        /// The person closed the sign-in window. Nothing to explain.
        case cancelled
        case network
        /// The person declined the permissions on the consent screen.
        case denied
        /// The provider signed the person in but did not share an address.
        case missingEmail = "missing_email"
        case other
    }

    let id = UUID()
    let provider: AccountType
    let kind: Kind
    private let errorDomain: String?
    private let errorCode: Int?
    private let oauthError: String?
    private let aadstsCode: String?

    init(provider: AccountType, error: Error) {
        let nsError = error as NSError
        let response = nsError.userInfo[OIDOAuthErrorResponseErrorKey] as? [String: Any]
        let rawOAuthError = response?[OIDOAuthErrorFieldError] as? String
        let description = (response?[OIDOAuthErrorFieldErrorDescription] as? String) ?? ""

        self.provider = provider
        self.errorDomain = nsError.domain
        self.errorCode = nsError.code
        self.oauthError = rawOAuthError.flatMap(Self.plainCode)
        self.aadstsCode = Self.aadstsCode(in: description)
        self.kind = Self.classify(provider: provider, error: nsError,
                                  oauthError: rawOAuthError, description: description,
                                  aadstsCode: aadstsCode)
    }

    private init(provider: AccountType, kind: Kind) {
        self.provider = provider
        self.kind = kind
        self.errorDomain = nil
        self.errorCode = nil
        self.oauthError = nil
        self.aadstsCode = nil
    }

    static func missingEmail(provider: AccountType) -> SigninFailure {
        SigninFailure(provider: provider, kind: .missingEmail)
    }

    /// Whether the person should see an explanation at all.
    var shouldExplain: Bool { kind != .cancelled }

    // MARK: Words

    static let title = NSLocalizedString("Couldn't sign in", comment: "Sign-in failure alert title")

    var message: String {
        let company = provider == .outlook ? "Microsoft" : "Google"
        switch kind {
        case .adminConsentRequired:
            return NSLocalizedString(
                "Your organization needs to approve Mail Notifier. Ask your IT administrator to approve it, or send them this link.",
                comment: "Sign-in failure: admin consent required")
        case .network:
            return String(format: NSLocalizedString(
                "Mail Notifier couldn't reach %@. Check your internet connection, then try again.",
                comment: "Sign-in failure: no connection. %@ is Microsoft or Google"), company)
        case .denied:
            return NSLocalizedString(
                "Mail Notifier needs permission to read your mail. Try again and allow access.",
                comment: "Sign-in failure: permission declined")
        case .missingEmail:
            return String(format: NSLocalizedString(
                "%@ didn't share the email address for this account. Try again, or use a different account.",
                comment: "Sign-in failure: no email. %@ is Microsoft or Google"), company)
        case .cancelled, .other:
            return String(format: NSLocalizedString(
                "Signing in to %@ didn't finish. Try again.",
                comment: "Sign-in failure: anything else. %@ is Microsoft or Google"), company)
        }
    }

    /// The link an administrator opens to approve the app for their whole
    /// organization. `organizations` lets Microsoft pick the admin's own tenant.
    static func adminConsentURL(clientID: String, tenant: String = "organizations") -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "login.microsoftonline.com"
        components.path = "/\(tenant)/adminconsent"
        components.queryItems = [URLQueryItem(name: "client_id", value: clientID)]
        return components.url ?? URL(string: "https://login.microsoftonline.com/organizations/adminconsent")!
    }

    // MARK: Analytics

    var telemetryProperties: [String: Any] {
        var props: [String: Any] = ["provider": provider.rawValue, "failure_kind": kind.rawValue]
        if kind == .missingEmail { props["reason"] = "no_email" }
        if let errorDomain { props["error_domain"] = errorDomain }
        if let errorCode { props["error_code"] = errorCode }
        if let oauthError { props["oauth_error"] = oauthError }
        if let aadstsCode { props["aadsts_code"] = aadstsCode }
        return props
    }

    // MARK: Classification

    private static let adminConsentCodes: Set<String> = ["AADSTS65001", "AADSTS90094", "AADSTS90095"]

    private static func classify(provider: AccountType, error: NSError, oauthError: String?,
                                 description: String, aadstsCode: String?) -> Kind {
        if error.domain == OIDGeneralErrorDomain,
           error.code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue
            || error.code == OIDErrorCode.programCanceledAuthorizationFlow.rawValue {
            return .cancelled
        }
        if isNetwork(error) { return .network }

        if provider == .outlook {
            if let aadstsCode, adminConsentCodes.contains(aadstsCode) { return .adminConsentRequired }
            if oauthError == "consent_required" { return .adminConsentRequired }
            if oauthError == "interaction_required", description.lowercased().contains("admin") {
                return .adminConsentRequired
            }
        }
        if oauthError == "access_denied" { return .denied }
        return .other
    }

    private static func isNetwork(_ error: NSError) -> Bool {
        if error.domain == NSURLErrorDomain { return true }
        if error.domain == OIDGeneralErrorDomain, error.code == OIDErrorCode.networkError.rawValue { return true }
        return false
    }

    /// OAuth error codes are short snake_case words. Anything else is dropped
    /// rather than risk sending free text.
    private static func plainCode(_ value: String) -> String? {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz_")
        guard !value.isEmpty, value.count <= 64,
              value.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return value
    }

    private static func aadstsCode(in description: String) -> String? {
        guard let range = description.range(of: #"AADSTS\d{4,6}"#, options: .regularExpression) else {
            return nil
        }
        return String(description[range])
    }
}
