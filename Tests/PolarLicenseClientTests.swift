//
//  PolarLicenseClientTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Covers the parts of the Polar client that decide whether someone is a
//  subscriber: response parsing, HTTP status mapping, and the benefit pin. All
//  of it is static and pure, so none of these tests touch the network.
//

import XCTest
@testable import Mail_Notifier

final class PolarLicenseClientTests: XCTestCase {

    // MARK: Fixtures

    private func data(_ json: String) -> Data {
        Data(json.utf8)
    }

    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.polar.sh/v1/x")!,
                        statusCode: code,
                        httpVersion: nil,
                        headerFields: nil)!
    }

    // MARK: Validate parsing

    func testGrantedKeyWithoutExpiryParses() throws {
        let status = try PolarLicenseClient.decodeStatus(data("""
        {"id":"lk_1","status":"granted","expires_at":null,
         "benefit_id":"ben_1","customer_id":"cus_1"}
        """))

        XCTAssertEqual(status.state, .granted)
        XCTAssertTrue(status.isGranted)
        XCTAssertNil(status.expiresAt)
        XCTAssertEqual(status.benefitId, "ben_1")
        XCTAssertEqual(status.customerId, "cus_1")
    }

    func testExpiryParsesWithAndWithoutFractionalSeconds() throws {
        let plain = try PolarLicenseClient.decodeStatus(data("""
        {"status":"granted","expires_at":"2027-03-01T12:00:00Z"}
        """))
        let fractional = try PolarLicenseClient.decodeStatus(data("""
        {"status":"granted","expires_at":"2027-03-01T12:00:00.123Z"}
        """))

        // Polar sends fractional seconds on some payloads and not others, and a
        // strict ISO8601 formatter returns nil for whichever shape it wasn't
        // configured for. Both have to land.
        XCTAssertNotNil(plain.expiresAt)
        XCTAssertNotNil(fractional.expiresAt)
        XCTAssertEqual(plain.expiresAt?.timeIntervalSince1970 ?? 0,
                       fractional.expiresAt?.timeIntervalSince1970 ?? 0,
                       accuracy: 1)
    }

    func testRevokedKeyIsNotGranted() throws {
        let status = try PolarLicenseClient.decodeStatus(data(#"{"status":"revoked"}"#))
        XCTAssertEqual(status.state, .revoked)
        XCTAssertFalse(status.isGranted)
    }

    func testUnrecognizedStatusIsUnknownAndNotGranted() throws {
        let status = try PolarLicenseClient.decodeStatus(data(#"{"status":"pending_review"}"#))
        XCTAssertEqual(status.state, .unknown)
        XCTAssertFalse(status.isGranted)
    }

    func testCustomerIdFallsBackToNestedCustomerObject() throws {
        let status = try PolarLicenseClient.decodeStatus(data("""
        {"status":"granted","customer":{"id":"cus_nested"}}
        """))
        XCTAssertEqual(status.customerId, "cus_nested")
    }

    func testUnreadableResponseThrows() {
        XCTAssertThrowsError(try PolarLicenseClient.decodeStatus(data("not json"))) { error in
            guard case LicenseError.invalidResponse = error else {
                return XCTFail("Expected .invalidResponse, got \(error)")
            }
        }
    }

    // MARK: Activation parsing

    func testActivationReadsIdAndNestedStatus() throws {
        let activation = try PolarLicenseClient.decodeActivation(data("""
        {"id":"act_1","license_key":{"status":"granted","benefit_id":"ben_1"}}
        """))

        XCTAssertEqual(activation.activationId, "act_1")
        XCTAssertEqual(activation.status.state, .granted)
        XCTAssertEqual(activation.status.benefitId, "ben_1")
    }

    func testActivationWithoutNestedKeyStillYieldsAnActivationId() throws {
        // The activation id is what gets persisted and replayed on validate and
        // deactivate, so a response we can't fully read must not cost us it.
        let activation = try PolarLicenseClient.decodeActivation(data(#"{"id":"act_2"}"#))
        XCTAssertEqual(activation.activationId, "act_2")
        XCTAssertEqual(activation.status.state, .unknown)
    }

    // MARK: HTTP status mapping

    func testSuccessStatusPasses() {
        XCTAssertNoThrow(try PolarLicenseClient.checkStatus(response(200), data: Data()))
    }

    func testNotFoundIsAnInvalidKey() {
        XCTAssertThrowsError(try PolarLicenseClient.checkStatus(response(404), data: Data())) { error in
            XCTAssertEqual(error as? LicenseError, .invalidKey)
        }
    }

    func testActivationLimitIsCalledOutByName() {
        let body = data(#"{"detail":"License key activation limit reached"}"#)
        XCTAssertThrowsError(try PolarLicenseClient.checkStatus(response(403), data: body)) { error in
            XCTAssertEqual(error as? LicenseError, .activationLimitReached)
        }
    }

    func testOtherFailuresCarryTheStatusAndMessage() {
        let body = data(#"{"detail":"Something went wrong"}"#)
        XCTAssertThrowsError(try PolarLicenseClient.checkStatus(response(500), data: body)) { error in
            XCTAssertEqual(error as? LicenseError,
                           .requestFailed(status: 500, message: "Something went wrong"))
        }
    }

    func testFastAPIValidationErrorShapeIsReadable() {
        let body = data(#"{"detail":[{"msg":"field required","loc":["body","key"]}]}"#)
        XCTAssertEqual(PolarLicenseClient.errorMessage(body), "field required")
    }

    func testUnparseableErrorBodyFallsBackToItsText() {
        XCTAssertEqual(PolarLicenseClient.errorMessage(data("upstream timeout")), "upstream timeout")
    }

    // MARK: Benefit pin

    func testKeyFromAnotherBenefitIsRejected() {
        let status = LicenseStatus(state: .granted, expiresAt: nil, customerId: nil, benefitId: "ben_other")
        XCTAssertThrowsError(try PolarLicenseClient.checkBenefit(status, expected: "ben_ours")) { error in
            XCTAssertEqual(error as? LicenseError, .wrongProduct)
        }
    }

    func testMatchingBenefitPasses() {
        let status = LicenseStatus(state: .granted, expiresAt: nil, customerId: nil, benefitId: "ben_ours")
        XCTAssertNoThrow(try PolarLicenseClient.checkBenefit(status, expected: "ben_ours"))
    }

    func testNoConfiguredBenefitAcceptsAnyKeyInTheOrganization() {
        let status = LicenseStatus(state: .granted, expiresAt: nil, customerId: nil, benefitId: "ben_other")
        XCTAssertNoThrow(try PolarLicenseClient.checkBenefit(status, expected: ""))
    }

    func testMissingBenefitInResponseDoesNotLockOutAPayingCustomer() {
        // The organization scope is the real boundary. If Polar stops sending
        // benefit_id, the pin has to fail open or every subscriber loses access
        // on the same day.
        let status = LicenseStatus(state: .granted, expiresAt: nil, customerId: nil, benefitId: nil)
        XCTAssertNoThrow(try PolarLicenseClient.checkBenefit(status, expected: "ben_ours"))
    }
}
