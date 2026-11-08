import XCTest
@testable import Mail_Notifier

final class SuppressedNotificationStoreTests: XCTestCase {
    func testSuppressedIDsPersistAcrossStoreInstances() {
        let defaults = UserDefaults(suiteName: "MailNotifierTests.SuppressedNotificationStore")!
        defer { defaults.removePersistentDomain(forName: "MailNotifierTests.SuppressedNotificationStore") }
        defaults.removePersistentDomain(forName: "MailNotifierTests.SuppressedNotificationStore")

        SuppressedNotificationStore(defaults: defaults, key: "test", limit: 3).mark(["first", "second"])

        XCTAssertTrue(SuppressedNotificationStore(defaults: defaults, key: "test", limit: 3).contains("first"))
        XCTAssertFalse(SuppressedNotificationStore(defaults: defaults, key: "test", limit: 3).contains("third"))
    }

    func testStoreDeduplicatesAndRemovesOldestIDsAtLimit() {
        let defaults = UserDefaults(suiteName: "MailNotifierTests.SuppressedNotificationStoreLimit")!
        defer { defaults.removePersistentDomain(forName: "MailNotifierTests.SuppressedNotificationStoreLimit") }
        defaults.removePersistentDomain(forName: "MailNotifierTests.SuppressedNotificationStoreLimit")

        let store = SuppressedNotificationStore(defaults: defaults, key: "test", limit: 3)
        store.mark(["first", "second", "second"])
        store.mark(["third", "fourth"])

        XCTAssertFalse(store.contains("first"))
        XCTAssertTrue(store.contains("second"))
        XCTAssertTrue(store.contains("third"))
        XCTAssertTrue(store.contains("fourth"))
    }
}
