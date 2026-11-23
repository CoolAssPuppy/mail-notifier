//
//  CrashReportingTests.swift
//  MailNotifierTests
//
//  Crash reporting starts only from a real DSN. A dev build or a fork has the
//  unsubstituted build setting in Info.plist and must stay off.
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class CrashReportingTests: XCTestCase {

    func testMissingOrEmptyDSNIsUnusable() {
        XCTAssertNil(CrashReporting.usableDSN(nil))
        XCTAssertNil(CrashReporting.usableDSN(""))
        XCTAssertNil(CrashReporting.usableDSN("   "))
    }

    func testUnsubstitutedBuildSettingIsUnusable() {
        XCTAssertNil(CrashReporting.usableDSN("$(SENTRY_DSN)"))
    }

    func testRealDSNIsUsed() {
        XCTAssertEqual(CrashReporting.usableDSN(" https://key@o1.ingest.us.sentry.io/42 "),
                       "https://key@o1.ingest.us.sentry.io/42")
    }
}
