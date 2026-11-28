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
import Sentry
@testable import Mail_Notifier

final class CrashReportingTests: XCTestCase {

    func testTelemetryTransportsBlockRequestsWhenConsentIsOff() async throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: Telemetry.optInKey)
        defer { defaults.set(previous, forKey: Telemetry.optInKey) }
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://telemetry.example.invalid/")))
        let options = Options()
        CrashReporting.configure(options, dsn: "http://test@localhost/1")
        let sentry = try XCTUnwrap(options.urlSession)
        let analytics = URLSession(configuration: TelemetryConsentProtocol.sessionConfiguration())

        defaults.set(false, forKey: Telemetry.optInKey)
        for session in [sentry, analytics] {
            do {
                _ = try await session.data(for: request)
                XCTFail("Telemetry request was allowed while off")
            } catch let error as URLError {
                XCTAssertEqual(error.code, .cancelled)
            }
        }
        defaults.set(true, forKey: Telemetry.optInKey)
        XCTAssertFalse(TelemetryConsentProtocol.canInit(with: request))
    }

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

    func testReleaseNameMatchesCocoaDefault() {
        XCTAssertEqual(
            CrashReporting.releaseName(identifier: "com.strategicnerds.MailNotifierApp",
                                       version: "3.9.0",
                                       build: "38"),
            "com.strategicnerds.MailNotifierApp@3.9.0+38"
        )
    }

    func testReleaseNameOmitsBuildWhenMissing() {
        XCTAssertEqual(
            CrashReporting.releaseName(identifier: "com.example.App", version: "1.0.0", build: nil),
            "com.example.App@1.0.0"
        )
        XCTAssertEqual(
            CrashReporting.releaseName(identifier: "com.example.App", version: "1.0.0", build: ""),
            "com.example.App@1.0.0"
        )
    }

    func testReleaseNameRequiresIdentifierAndVersion() {
        XCTAssertNil(CrashReporting.releaseName(identifier: nil, version: "1.0", build: "1"))
        XCTAssertNil(CrashReporting.releaseName(identifier: "", version: "1.0", build: "1"))
        XCTAssertNil(CrashReporting.releaseName(identifier: "id", version: nil, build: "1"))
        XCTAssertNil(CrashReporting.releaseName(identifier: "id", version: "", build: "1"))
    }

    func testDistIsTheBuildNumber() {
        XCTAssertEqual(CrashReporting.dist("38"), "38")
        XCTAssertEqual(CrashReporting.dist(" 38 "), "38")
        XCTAssertNil(CrashReporting.dist(nil))
        XCTAssertNil(CrashReporting.dist(""))
        XCTAssertNil(CrashReporting.dist("   "))
    }

    func testEnvironmentIsDebugInTestBuilds() {
        XCTAssertEqual(CrashReporting.environment, "debug")
    }

    func testHostAppReleaseNameMatchesCocoaDefault() throws {
        let identifier = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let version = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let build = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String)
        XCTAssertEqual(identifier, "com.strategicnerds.MailNotifierApp")
        XCTAssertEqual(
            CrashReporting.releaseName(identifier: identifier, version: version, build: build),
            "\(identifier)@\(version)+\(build)"
        )
        XCTAssertEqual(CrashReporting.dist(build), build)
    }
}
