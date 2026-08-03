//
//  EntitlementManagerTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  The rules that decide whether a subscriber keeps their accounts: the gate,
//  the grace behavior when Polar can't be reached, and the daily check's
//  midnight math. All pure statics, no network and no clock.
//

import XCTest
@testable import Mail_Notifier

final class EntitlementManagerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func record(_ state: LicenseStatus.State,
                        expiresAt: Date? = nil) -> EntitlementRecord {
        EntitlementRecord(statusRaw: state.rawValue,
                          expiresAt: expiresAt,
                          customerId: "cus_1",
                          lastValidatedAt: now)
    }

    private func status(_ state: LicenseStatus.State,
                        expiresAt: Date? = nil) -> LicenseStatus {
        LicenseStatus(state: state, expiresAt: expiresAt, customerId: "cus_1", benefitId: "ben_1")
    }

    // MARK: The gate

    func testNoRecordIsNotEntitled() {
        XCTAssertFalse(EntitlementManager.isEntitled(record: nil, now: now))
    }

    func testGrantedWithoutExpiryIsEntitled() {
        // The normal case for this product: the Polar benefit sets no TTL, so
        // revocation rather than expiry is what ends a subscription.
        XCTAssertTrue(EntitlementManager.isEntitled(record: record(.granted), now: now))
    }

    func testGrantedBeforeExpiryIsEntitled() {
        let record = record(.granted, expiresAt: now.addingTimeInterval(86_400))
        XCTAssertTrue(EntitlementManager.isEntitled(record: record, now: now))
    }

    func testGrantedPastExpiryIsNotEntitled() {
        let record = record(.granted, expiresAt: now.addingTimeInterval(-1))
        XCTAssertFalse(EntitlementManager.isEntitled(record: record, now: now))
    }

    func testRevokedIsNotEntitledEvenWithAFutureExpiry() {
        // Cancelling mid-term revokes the key while its expiry is still ahead.
        // Status has to win, or a cancellation would take a year to bite.
        let record = record(.revoked, expiresAt: now.addingTimeInterval(86_400))
        XCTAssertFalse(EntitlementManager.isEntitled(record: record, now: now))
    }

    func testDisabledIsNotEntitled() {
        XCTAssertFalse(EntitlementManager.isEntitled(record: record(.disabled), now: now))
    }

    func testUnknownStatusIsNotEntitled() {
        let record = EntitlementRecord(statusRaw: "something_new",
                                       expiresAt: nil,
                                       customerId: nil,
                                       lastValidatedAt: now)
        XCTAssertFalse(EntitlementManager.isEntitled(record: record, now: now))
    }

    // MARK: Grace

    func testSuccessfulValidateReplacesTheRecord() {
        let updated = EntitlementManager.reduce(current: record(.revoked),
                                                result: .success(status(.granted)),
                                                now: now)
        XCTAssertEqual(updated?.state, .granted)
        XCTAssertEqual(updated?.lastValidatedAt, now)
    }

    func testNetworkFailureKeepsTheExistingRecord() {
        // Someone on a plane keeps their accounts. This is the whole point of
        // grace: an outage is not a cancellation.
        let current = record(.granted)
        let updated = EntitlementManager.reduce(current: current,
                                                result: .failure(URLError(.notConnectedToInternet)),
                                                now: now)
        XCTAssertEqual(updated, current)
        XCTAssertTrue(EntitlementManager.isEntitled(record: updated, now: now))
    }

    func testServerErrorKeepsTheExistingRecord() {
        let current = record(.granted)
        let failure = LicenseError.requestFailed(status: 503, message: "upstream")
        let updated = EntitlementManager.reduce(current: current,
                                                result: .failure(failure),
                                                now: now)
        XCTAssertEqual(updated, current)
    }

    func testInvalidKeyLapsesImmediately() {
        let updated = EntitlementManager.reduce(current: record(.granted),
                                                result: .failure(LicenseError.invalidKey),
                                                now: now)
        XCTAssertEqual(updated?.state, .revoked)
        XCTAssertFalse(EntitlementManager.isEntitled(record: updated, now: now))
    }

    func testKeyForAnotherProductLapsesImmediately() {
        let updated = EntitlementManager.reduce(current: record(.granted),
                                                result: .failure(LicenseError.wrongProduct),
                                                now: now)
        XCTAssertEqual(updated?.state, .revoked)
    }

    func testFailureWithNoPriorRecordStaysEmpty() {
        let updated = EntitlementManager.reduce(current: nil,
                                                result: .failure(URLError(.timedOut)),
                                                now: now)
        XCTAssertNil(updated)
    }

    // MARK: Daily check

    func testSecondsUntilMidnightIsPositiveAndWithinADay() {
        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        let seconds = EntitlementManager.secondsUntilNextMidnight(after: now, in: pacific)
        XCTAssertGreaterThan(seconds, 0)
        XCTAssertLessThanOrEqual(seconds, 86_400)
    }

    func testMidnightIsComputedInTheGivenZoneNotTheDeviceZone() {
        // Running the daily check at the same wall-clock moment for everyone is
        // the point; a device in Tokyo must not get a different answer.
        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertNotEqual(EntitlementManager.secondsUntilNextMidnight(after: now, in: pacific),
                          EntitlementManager.secondsUntilNextMidnight(after: now, in: tokyo))
    }

    func testSecondsUntilMidnightLandsOnMidnight() {
        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific

        let seconds = EntitlementManager.secondsUntilNextMidnight(after: now, in: pacific)
        let arrival = now.addingTimeInterval(seconds)
        let parts = calendar.dateComponents([.hour, .minute, .second], from: arrival)

        XCTAssertEqual(parts.hour, 0)
        XCTAssertEqual(parts.minute, 0)
        XCTAssertEqual(parts.second, 0)
    }

    // MARK: Persistence shape

    func testRecordSurvivesAnEncodeDecodeRoundTrip() {
        let original = record(.granted, expiresAt: now.addingTimeInterval(31_536_000))
        let data = try? JSONEncoder().encode(original)
        let decoded = data.flatMap { try? JSONDecoder().decode(EntitlementRecord.self, from: $0) }
        XCTAssertEqual(decoded, original)
    }
}
