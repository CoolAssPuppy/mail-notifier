//
//  SigninFailureTests.swift
//  MailNotifierTests
//
//  A failed sign-in is sorted into what the person can do about it, and
//  reported to analytics with the error's domain, code and OAuth error string
//  only. The error description can carry an email address or a tenant name,
//  so it never leaves the device.
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
import AppAuth
@testable import Mail_Notifier

final class SigninFailureTests: XCTestCase {

    private func oauthError(domain: String = OIDOAuthAuthorizationErrorDomain,
                            code: Int = -10,
                            error: String,
                            description: String? = nil) -> NSError {
        var response: [String: Any] = [OIDOAuthErrorFieldError: error]
        if let description { response[OIDOAuthErrorFieldErrorDescription] = description }
        return NSError(domain: domain, code: code, userInfo: [
            OIDOAuthErrorResponseErrorKey: response,
            NSLocalizedDescriptionKey: "\(error): \(description ?? "")"
        ])
    }

    // MARK: - Admin consent

    func testConsentRequiredNeedsAnAdministrator() {
        let failure = SigninFailure(provider: .outlook, error: oauthError(error: "consent_required"))
        XCTAssertEqual(failure.kind, .adminConsentRequired)
    }

    func testAADSTS65001NeedsAnAdministrator() {
        let failure = SigninFailure(provider: .outlook, error: oauthError(
            error: "invalid_grant",
            description: "AADSTS65001: The user or administrator has not consented to use the application."))
        XCTAssertEqual(failure.kind, .adminConsentRequired)
        XCTAssertEqual(failure.telemetryProperties["aadsts_code"] as? String, "AADSTS65001")
    }

    func testAADSTS90094And90095NeedAnAdministrator() {
        for code in ["AADSTS90094", "AADSTS90095"] {
            let failure = SigninFailure(provider: .outlook, error: oauthError(
                error: "access_denied", description: "\(code): Admin consent is required."))
            XCTAssertEqual(failure.kind, .adminConsentRequired, code)
        }
    }

    func testInteractionRequiredNeedsAnAdministratorOnlyWithAdminWording() {
        let admin = SigninFailure(provider: .outlook, error: oauthError(
            error: "interaction_required", description: "Your administrator must approve this app."))
        let plain = SigninFailure(provider: .outlook, error: oauthError(
            error: "interaction_required", description: "Multi-factor authentication is required."))
        XCTAssertEqual(admin.kind, .adminConsentRequired)
        XCTAssertNotEqual(plain.kind, .adminConsentRequired)
    }

    func testGoogleConsentErrorsNeverAskForAMicrosoftAdministrator() {
        let failure = SigninFailure(provider: .gmail, error: oauthError(error: "consent_required"))
        XCTAssertNotEqual(failure.kind, .adminConsentRequired)
    }

    func testAdminConsentMessageAndLink() {
        let failure = SigninFailure(provider: .outlook, error: oauthError(error: "consent_required"))
        XCTAssertEqual(failure.message,
                       "Your organization needs to approve Mail Notifier. Ask your IT administrator to approve it, or send them this link.")
        XCTAssertEqual(SigninFailure.adminConsentURL(clientID: "abc-123").absoluteString,
                       "https://login.microsoftonline.com/organizations/adminconsent?client_id=abc-123")
        XCTAssertEqual(SigninFailure.adminConsentURL(clientID: "abc-123", tenant: "contoso.onmicrosoft.com").absoluteString,
                       "https://login.microsoftonline.com/contoso.onmicrosoft.com/adminconsent?client_id=abc-123")
    }

    // MARK: - Other kinds

    func testClosingTheSignInWindowIsACancel() {
        let error = NSError(domain: OIDGeneralErrorDomain, code: OIDErrorCode.userCanceledAuthorizationFlow.rawValue)
        XCTAssertEqual(SigninFailure(provider: .gmail, error: error).kind, .cancelled)
    }

    func testNoConnectionIsANetworkFailure() {
        let direct = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let wrapped = NSError(domain: OIDGeneralErrorDomain, code: OIDErrorCode.networkError.rawValue,
                              userInfo: [NSUnderlyingErrorKey: direct])
        XCTAssertEqual(SigninFailure(provider: .gmail, error: direct).kind, .network)
        XCTAssertEqual(SigninFailure(provider: .outlook, error: wrapped).kind, .network)
        XCTAssertEqual(SigninFailure(provider: .outlook, error: wrapped).message,
                       "Mail Notifier couldn't reach Microsoft. Check your internet connection, then try again.")
    }

    func testDecliningPermissionIsDenied() {
        let failure = SigninFailure(provider: .gmail, error: oauthError(error: "access_denied"))
        XCTAssertEqual(failure.kind, .denied)
        XCTAssertEqual(failure.message,
                       "Mail Notifier needs permission to read your mail. Try again and allow access.")
    }

    func testMissingEmailHasItsOwnExplanation() {
        let failure = SigninFailure.missingEmail(provider: .outlook)
        XCTAssertEqual(failure.kind, .missingEmail)
        XCTAssertEqual(failure.message,
                       "Microsoft didn't share the email address for this account. Try again, or use a different account.")
    }

    func testAnythingElseGetsTheGeneralExplanation() {
        let failure = SigninFailure(provider: .gmail, error: NSError(domain: "com.example", code: 7))
        XCTAssertEqual(failure.kind, .other)
        XCTAssertEqual(failure.message, "Signing in to Google didn't finish. Try again.")
    }

    // MARK: - Analytics

    func testAnalyticsCarryDomainCodeAndOAuthError() {
        let failure = SigninFailure(provider: .outlook, error: oauthError(code: -10, error: "invalid_client"))
        let props = failure.telemetryProperties
        XCTAssertEqual(props["provider"] as? String, "outlook")
        XCTAssertEqual(props["error_domain"] as? String, OIDOAuthAuthorizationErrorDomain)
        XCTAssertEqual(props["error_code"] as? Int, -10)
        XCTAssertEqual(props["oauth_error"] as? String, "invalid_client")
        XCTAssertEqual(props["failure_kind"] as? String, "other")
    }

    func testAnalyticsNeverCarryTheErrorDescription() {
        let failure = SigninFailure(provider: .outlook, error: oauthError(
            error: "invalid_grant",
            description: "AADSTS50020: User account 'person@contoso.com' from identity provider does not exist in tenant 'Contoso'."))
        for (key, value) in failure.telemetryProperties {
            let text = String(describing: value)
            XCTAssertFalse(text.contains("@"), "\(key) leaked an email address")
            XCTAssertFalse(text.contains("Contoso"), "\(key) leaked a tenant name")
        }
    }

    func testAnOAuthErrorThatIsNotAPlainCodeIsDropped() {
        let failure = SigninFailure(provider: .outlook, error: oauthError(error: "person@contoso.com"))
        XCTAssertNil(failure.telemetryProperties["oauth_error"])
    }
}
