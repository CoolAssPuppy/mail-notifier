//
//  VIPListTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class VIPListTests: XCTestCase {

    private static let suiteName = "MailNotifierTests.VIPList"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        VIPList.defaults = defaults
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        VIPList.defaults = .standard
        super.tearDown()
    }

    // MARK: - Round-trip

    func testEmptyRawValueDecodesToEmptyList() {
        XCTAssertEqual(VIPList(rawValue: "[]")?.count, 0)
    }

    func testRawValueRoundTrip() {
        let original: VIPList = [
            VIP(email: "ceo@company.com", notificationSound: "blow"),
            VIP(email: "spouse@home.com", notificationSound: "ping")
        ]
        let restored = VIPList(rawValue: original.rawValue)
        XCTAssertEqual(restored?.count, 2)
        XCTAssertEqual(restored?.first?.email, "ceo@company.com")
        XCTAssertEqual(restored?.first?.notificationSound, "blow")
    }

    // MARK: - CRUD

    func testAddPersists() {
        var list = VIPList.default
        list.add(vip: VIP(email: "Boss@company.com", notificationSound: "frog"))

        let reloaded = VIPList.default
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.email, "Boss@company.com")
    }

    func testAddIsCaseInsensitiveDuplicateGuard() {
        var list = VIPList.default
        list.add(vip: VIP(email: "Boss@company.com", notificationSound: "frog"))
        list.add(vip: VIP(email: "boss@COMPANY.com", notificationSound: "ping"))

        let reloaded = VIPList.default
        XCTAssertEqual(reloaded.count, 1, "Different casing of the same email must not duplicate")
    }

    func testDeleteRemovesByEmail() {
        var list = VIPList.default
        let target = VIP(email: "remove@me.com", notificationSound: "frog")
        list.add(vip: target)
        XCTAssertEqual(VIPList.default.count, 1)

        list.delete(vip: target)
        XCTAssertEqual(VIPList.default.count, 0)
    }

    func testDeleteIsCaseInsensitive() {
        var list = VIPList.default
        list.add(vip: VIP(email: "User@Example.com", notificationSound: "frog"))
        list.delete(vip: VIP(email: "user@example.com", notificationSound: "different"))
        XCTAssertEqual(VIPList.default.count, 0)
    }

    func testUpdateChangesSound() {
        var list = VIPList.default
        list.add(vip: VIP(email: "v@i.p", notificationSound: "frog"))
        list.update(vip: VIP(email: "v@i.p", notificationSound: "ping"))

        XCTAssertEqual(VIPList.default.first?.notificationSound, "ping")
    }

    // MARK: - Sender lookup

    func testSoundForSenderReturnsNilForUnknown() {
        let list: VIPList = [VIP(email: "known@example.com", notificationSound: "frog")]
        XCTAssertNil(list.soundForSender("stranger@example.com"))
    }

    func testSoundForSenderIsCaseInsensitive() {
        let list: VIPList = [VIP(email: "Known@Example.com", notificationSound: "frog")]
        XCTAssertEqual(list.soundForSender("KNOWN@EXAMPLE.COM"), .frog)
    }
}
