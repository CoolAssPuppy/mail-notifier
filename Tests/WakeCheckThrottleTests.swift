//
//  WakeCheckThrottleTests.swift
//  MailNotifierTests
//
//  Waking the Mac and unlocking the screen arrive together. One check covers
//  both.
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class WakeCheckThrottleTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testTheFirstWakeChecks() {
        var throttle = WakeCheckThrottle()
        XCTAssertTrue(throttle.shouldCheck(at: start))
    }

    func testAnUnlockRightAfterAWakeDoesNotCheckAgain() {
        var throttle = WakeCheckThrottle()
        _ = throttle.shouldCheck(at: start)
        XCTAssertFalse(throttle.shouldCheck(at: start.addingTimeInterval(20)))
    }

    func testALaterWakeChecksAgain() {
        var throttle = WakeCheckThrottle()
        _ = throttle.shouldCheck(at: start)
        XCTAssertTrue(throttle.shouldCheck(at: start.addingTimeInterval(61)))
    }
}
