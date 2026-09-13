//
//  AccountIconStoreTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

/// Stands in for `NSUbiquitousKeyValueStore`, which has no iCloud entitlement
/// under the test host and would silently return nothing.
private final class InMemoryCloudStore: KeyValueCloudStore {
    private(set) var values: [String: Any] = [:]

    func data(forKey aKey: String) -> Data? { values[aKey] as? Data }

    func set(_ aData: Data?, forKey aKey: String) {
        if let aData { values[aKey] = aData } else { values.removeValue(forKey: aKey) }
    }

    func removeObject(forKey aKey: String) { values.removeValue(forKey: aKey) }

    @discardableResult func synchronize() -> Bool { true }

    var dictionaryRepresentation: [String: Any] { values }

    /// Pretends another Mac wrote these keys, the way iCloud announces it.
    func announceExternalChange(keys: [String]) {
        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: self,
            userInfo: [NSUbiquitousKeyValueStoreChangedKeysKey: keys]
        )
    }
}

final class AccountIconStoreTests: XCTestCase {

    private static let suiteName = "MailNotifierTests.AccountIconStore"
    private var defaults: UserDefaults!
    private var cloud: InMemoryCloudStore!

    private let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
    private let otherPNG = Data([0x89, 0x50, 0x4E, 0x47, 9, 9, 9])

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        cloud = InMemoryCloudStore()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        super.tearDown()
    }

    private func makeStore() -> AccountIconStore {
        AccountIconStore(defaults: defaults, cloud: cloud)
    }

    // MARK: - Set and read

    func testSetIconReadsBack() {
        let store = makeStore()
        store.setIcon(png, for: "me@example.com")
        XCTAssertEqual(store.icon(for: "me@example.com"), png)
    }

    func testIconIsNilWhenUnset() {
        XCTAssertNil(makeStore().icon(for: "nobody@example.com"))
    }

    func testSettingNilRemovesTheIcon() {
        let store = makeStore()
        store.setIcon(png, for: "me@example.com")
        store.setIcon(nil, for: "me@example.com")
        XCTAssertNil(store.icon(for: "me@example.com"))
        XCTAssertTrue(cloud.values.isEmpty, "removal has to reach the cloud too")
    }

    func testEmailLookupIgnoresCaseAndWhitespace() {
        let store = makeStore()
        store.setIcon(png, for: "  Me@Example.COM ")
        XCTAssertEqual(store.icon(for: "me@example.com"), png)
    }

    // MARK: - Persistence

    func testIconSurvivesANewStoreInstance() {
        makeStore().setIcon(png, for: "me@example.com")
        XCTAssertEqual(makeStore().icon(for: "me@example.com"), png)
    }

    func testIconSurvivesWhenTheCloudIsEmpty() {
        // A missing iCloud entitlement or a not-yet-populated KVS reads as
        // empty. That must never wipe what the person set on this Mac.
        makeStore().setIcon(png, for: "me@example.com")
        cloud = InMemoryCloudStore()
        XCTAssertEqual(makeStore().icon(for: "me@example.com"), png)
    }

    func testCloudValueWinsOverLocalAtLaunch() {
        makeStore().setIcon(png, for: "me@example.com")
        cloud.set(otherPNG, forKey: AccountIconStore.storageKey(for: "me@example.com"))
        XCTAssertEqual(makeStore().icon(for: "me@example.com"), otherPNG)
    }

    // MARK: - Roaming

    func testExternalChangeAppliesTheNewIcon() {
        let store = makeStore()
        store.start()
        let key = AccountIconStore.storageKey(for: "me@example.com")
        cloud.set(otherPNG, forKey: key)

        cloud.announceExternalChange(keys: [key])

        XCTAssertEqual(store.icon(for: "me@example.com"), otherPNG)
        XCTAssertEqual(defaults.data(forKey: key), otherPNG, "the local mirror follows the cloud")
    }

    func testExternalRemovalClearsTheIcon() {
        let store = makeStore()
        store.start()
        store.setIcon(png, for: "me@example.com")
        let key = AccountIconStore.storageKey(for: "me@example.com")
        cloud.removeObject(forKey: key)

        cloud.announceExternalChange(keys: [key])

        XCTAssertNil(store.icon(for: "me@example.com"))
        XCTAssertNil(defaults.data(forKey: key))
    }

    func testExternalChangeIgnoresUnrelatedKeys() {
        let store = makeStore()
        store.start()
        store.setIcon(png, for: "me@example.com")

        cloud.announceExternalChange(keys: ["friendlyNames"])

        XCTAssertEqual(store.icon(for: "me@example.com"), png)
    }

    func testExternalChangeOnlyTouchesTheNamedKeys() {
        // iCloud names the keys that changed. An icon it does not mention
        // stays put even if the cloud has no copy of it yet.
        let store = makeStore()
        store.start()
        store.setIcon(png, for: "keep@example.com")
        cloud.removeObject(forKey: AccountIconStore.storageKey(for: "keep@example.com"))
        let changed = AccountIconStore.storageKey(for: "new@example.com")
        cloud.set(otherPNG, forKey: changed)

        cloud.announceExternalChange(keys: [changed])

        XCTAssertEqual(store.icon(for: "keep@example.com"), png)
        XCTAssertEqual(store.icon(for: "new@example.com"), otherPNG)
    }
}
