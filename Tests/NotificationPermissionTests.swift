//
//  NotificationPermissionTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
import UserNotifications
@testable import Mail_Notifier

final class NotificationPermissionTests: XCTestCase {

    func testEverySystemStatusMapsToAState() {
        XCTAssertEqual(NotificationPermission(.authorized), .granted)
        XCTAssertEqual(NotificationPermission(.denied), .denied)
        XCTAssertEqual(NotificationPermission(.provisional), .provisional)
        XCTAssertEqual(NotificationPermission(.notDetermined), .notDetermined)
    }

    func testAnalyticsValues() {
        XCTAssertEqual(NotificationPermission.granted.analyticsValue, "granted")
        XCTAssertEqual(NotificationPermission.denied.analyticsValue, "denied")
        XCTAssertEqual(NotificationPermission.provisional.analyticsValue, "provisional")
        XCTAssertEqual(NotificationPermission.notDetermined.analyticsValue, "not_determined")
    }

    func testOnlyADenialIsShownAsBlocked() {
        XCTAssertTrue(NotificationPermission.denied.isBlocked)
        XCTAssertFalse(NotificationPermission.granted.isBlocked)
        XCTAssertFalse(NotificationPermission.provisional.isBlocked)
        XCTAssertFalse(NotificationPermission.notDetermined.isBlocked)
    }

    func testSettingsLinkOpensThisAppsNotificationSettings() {
        XCTAssertEqual(NotificationPermission.settingsURL(bundleID: "com.strategicnerds.MailNotifierApp").absoluteString,
                       "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.strategicnerds.MailNotifierApp")
    }
}
