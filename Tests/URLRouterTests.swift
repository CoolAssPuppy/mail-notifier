//
//  URLRouterTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class URLRouterTests: XCTestCase {

    // MARK: - Preferences

    func testPreferencesSchemeMatches() {
        let url = URL(string: "mailnotifier://preferences")!
        XCTAssertEqual(URLRouter.route(for: url), .preferences)
    }

    func testPreferencesIsCaseInsensitive() {
        let url = URL(string: "MAILNOTIFIER://PREFERENCES")!
        XCTAssertEqual(URLRouter.route(for: url), .preferences)
    }

    func testPreferencesRequiresHostMatch() {
        // Unknown host on the same scheme is not preferences.
        let url = URL(string: "mailnotifier://other")!
        XCTAssertNil(URLRouter.route(for: url))
    }

    // MARK: - mailto

    func testMailtoSchemeMatches() {
        let url = URL(string: "mailto:foo@bar.com")!
        XCTAssertEqual(URLRouter.route(for: url), .mailTo)
    }

    func testMailtoSchemeIsCaseInsensitive() {
        let url = URL(string: "MAILTO:foo@bar.com")!
        XCTAssertEqual(URLRouter.route(for: url), .mailTo)
    }

    // MARK: - Unknown

    func testUnknownHttpsURLRoutesToNothing() {
        let url = URL(string: "https://example.com/anything")!
        XCTAssertNil(URLRouter.route(for: url))
    }

    func testEmptySchemeRoutesToNothing() {
        // file: URLs without the right structure shouldn't match anything.
        let url = URL(string: "file:///etc/passwd")!
        XCTAssertNil(URLRouter.route(for: url))
    }

    // MARK: - Outlook OAuth callback shape

    func testOutlookOAuthCallbackRecognizedByShape() {
        // Reproduce the redirect URL shape that OutlookOAuthClient expects:
        //   msal<clientID>://auth/
        // We can't compute the real redirect scheme without a client ID at
        // build time, so verify the predicate directly.
        let scheme = OutlookOAuthClient.redirectScheme
        guard !scheme.isEmpty else {
            // No client ID configured in this build — accept the skip.
            return
        }
        let url = URL(string: "\(scheme)://auth/")!
        XCTAssertTrue(URLRouter.isOutlookOAuthCallback(url))
    }

    func testOutlookOAuthCallbackRejectsWrongHost() {
        let scheme = OutlookOAuthClient.redirectScheme
        guard !scheme.isEmpty else { return }
        let url = URL(string: "\(scheme)://intruder/")!
        XCTAssertFalse(URLRouter.isOutlookOAuthCallback(url))
    }

    // MARK: - Google OAuth callback shape

    func testGoogleOAuthCallbackRecognizedByShape() {
        let scheme = GoogleOAuthClient.redirectScheme
        guard !scheme.isEmpty else { return }
        let url = URL(string: "\(scheme):/oauthredirect")!
        XCTAssertTrue(URLRouter.isGoogleOAuthCallback(url))
    }

    func testGoogleOAuthCallbackRejectsWrongPath() {
        let scheme = GoogleOAuthClient.redirectScheme
        guard !scheme.isEmpty else { return }
        let url = URL(string: "\(scheme):/elsewhere")!
        XCTAssertFalse(URLRouter.isGoogleOAuthCallback(url))
    }
}
