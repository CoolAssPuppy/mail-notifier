//
//  MicrosoftIDTokenTests.swift
//  MailNotifierTests
//
//  Reads the claims Mail Notifier needs from a Microsoft ID token: the email
//  that names the account and the tenant that says whether it is a work or
//  school account or a personal one.
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class MicrosoftIDTokenTests: XCTestCase {

    private func jwt(_ claims: [String: Any]) -> String {
        let header = Data(#"{"alg":"none"}"#.utf8)
        let payload = try! JSONSerialization.data(withJSONObject: claims)
        func base64url(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(base64url(header)).\(base64url(payload)).sig"
    }

    private let workTenant = "72f988bf-86f1-41af-91ab-2d7cd011db47"

    func testPersonalAccountTenantIsTheConsumerTenant() {
        let token = MicrosoftIDToken(jwt: jwt(["tid": MicrosoftTenant.consumerTenantID,
                                               "email": "me@outlook.com"]))
        XCTAssertEqual(token?.tenantID, MicrosoftTenant.consumerTenantID)
        XCTAssertEqual(token?.isWorkOrSchool, false)
    }

    func testWorkAccountTenantIsItsOrganization() {
        let token = MicrosoftIDToken(jwt: jwt(["tid": workTenant, "preferred_username": "me@contoso.com"]))
        XCTAssertEqual(token?.tenantID, workTenant)
        XCTAssertEqual(token?.isWorkOrSchool, true)
    }

    func testTenantFallsBackToTheIssuer() {
        let token = MicrosoftIDToken(jwt: jwt(["iss": "https://login.microsoftonline.com/\(workTenant)/v2.0",
                                               "email": "me@contoso.com"]))
        XCTAssertEqual(token?.tenantID, workTenant)
        XCTAssertEqual(token?.isWorkOrSchool, true)
    }

    func testNoTenantClaimLeavesTheKindUnknown() {
        let token = MicrosoftIDToken(jwt: jwt(["email": "me@outlook.com"]))
        XCTAssertNil(token?.tenantID)
        XCTAssertNil(token?.isWorkOrSchool)
    }

    func testEmailPrefersEmailThenPreferredUsernameThenUPN() {
        XCTAssertEqual(MicrosoftIDToken(jwt: jwt(["email": "A@Outlook.com", "preferred_username": "b@x.com"]))?.email,
                       "a@outlook.com")
        XCTAssertEqual(MicrosoftIDToken(jwt: jwt(["email": "", "preferred_username": "B@Contoso.com"]))?.email,
                       "b@contoso.com")
        XCTAssertEqual(MicrosoftIDToken(jwt: jwt(["upn": "c@contoso.com"]))?.email, "c@contoso.com")
        XCTAssertNil(MicrosoftIDToken(jwt: jwt(["tid": workTenant]))?.email)
    }

    func testMalformedTokenIsRejected() {
        XCTAssertNil(MicrosoftIDToken(jwt: "not-a-token"))
        XCTAssertNil(MicrosoftIDToken(jwt: "a.%%%.c"))
    }
}
