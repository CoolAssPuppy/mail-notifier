//
//  AuthorizationErrorMappingTests.swift
//  MailNotifierTests
//
//  A refresh token that was revoked or expired has to show "Sign in again",
//  not a quiet network error. A dropped connection must still read as a
//  network error.
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
import AppAuth
@testable import Mail_Notifier

final class AuthorizationErrorMappingTests: XCTestCase {

    private var invalidGrant: NSError {
        NSError(domain: OIDOAuthTokenErrorDomain, code: OIDErrorCodeOAuth.invalidGrant.rawValue, userInfo: [
            OIDOAuthErrorResponseErrorKey: [OIDOAuthErrorFieldError: "invalid_grant"]
        ])
    }

    private func isAuthRequired(_ error: MailProviderError) -> Bool {
        if case .authenticationRequired = error { return true }
        return false
    }

    private func isNetwork(_ error: MailProviderError) -> Bool {
        if case .networkError = error { return true }
        return false
    }

    // MARK: - Outlook

    func testOutlookRevokedRefreshTokenNeedsSignIn() {
        XCTAssertTrue(isAuthRequired(OutlookProvider.mapAuthorizationError(invalidGrant)))
    }

    func testOutlookRefreshWithoutARefreshTokenNeedsSignIn() {
        let error = NSError(domain: OIDGeneralErrorDomain, code: OIDErrorCode.tokenRefreshError.rawValue)
        XCTAssertTrue(isAuthRequired(OutlookProvider.mapAuthorizationError(error)))
    }

    func testOutlookRefreshOverADroppedConnectionIsANetworkError() {
        let error = NSError(domain: OIDGeneralErrorDomain, code: OIDErrorCode.networkError.rawValue,
                            userInfo: [NSUnderlyingErrorKey: URLError(.notConnectedToInternet)])
        XCTAssertTrue(isNetwork(OutlookProvider.mapAuthorizationError(error)))
        XCTAssertTrue(isNetwork(OutlookProvider.mapAuthorizationError(URLError(.timedOut))))
    }

    // MARK: - Gmail

    func testGmailRevokedRefreshTokenNeedsSignIn() {
        XCTAssertTrue(isAuthRequired(GmailProvider.mapGmailError(invalidGrant)))
    }

    func testGmailRevokedRefreshTokenWrappedByTheFetcherNeedsSignIn() {
        let wrapped = NSError(domain: "com.google.HTTPStatus", code: -1,
                              userInfo: [NSUnderlyingErrorKey: invalidGrant])
        XCTAssertTrue(isAuthRequired(GmailProvider.mapGmailError(wrapped)))
    }
}
