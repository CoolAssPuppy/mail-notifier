//
//  AccountIconStore.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation
import Combine

/// The slice of `NSUbiquitousKeyValueStore` the icon store uses, so tests can
/// swap in a dictionary. The real store has no iCloud entitlement under the
/// test host and would read back nothing.
protocol KeyValueCloudStore: AnyObject {
    func data(forKey aKey: String) -> Data?
    func set(_ aData: Data?, forKey aKey: String)
    func removeObject(forKey aKey: String)
    @discardableResult func synchronize() -> Bool
    var dictionaryRepresentation: [String: Any] { get }
}

extension NSUbiquitousKeyValueStore: KeyValueCloudStore {}

/// Keyed map of account email → custom icon, as PNG bytes.
///
/// Same shape as `FriendlyNameStore`: iCloud Key-Value Storage so icons roam
/// across Macs signed into the same Apple ID, with a `UserDefaults` mirror so
/// reads are fast and the feature still works when iCloud is unavailable.
///
/// One cloud key per account rather than one dictionary of all of them. KVS
/// caps a single value at 1 MB and silently drops a write over the limit, so
/// per-account keys mean one oversized icon can't take the others down with
/// it. It also makes removal roam: the change notification names the keys
/// that moved, and a named key with no cloud value is a removal.
///
/// Icons are not cleared when an account is removed, matching friendly names.
/// The account list is per Mac but icons roam, so a delete on one Mac must
/// not strip the icon from another that still has the account.
final class AccountIconStore: ObservableObject {
    static let shared = AccountIconStore()

    @Published private(set) var icons: [String: Data] = [:]

    static let keyPrefix = "accountIcon."

    private let defaults: UserDefaults
    private let cloud: KeyValueCloudStore
    private var cloudObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard,
         cloud: KeyValueCloudStore = NSUbiquitousKeyValueStore.default) {
        self.defaults = defaults
        self.cloud = cloud
        icons = readMerged()
    }

    deinit {
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
        }
    }

    // MARK: - Public API

    func icon(for email: String) -> Data? {
        icons[Self.normalize(email)]
    }

    /// `nil` removes the custom icon and the account goes back to its
    /// provider's brand mark.
    func setIcon(_ data: Data?, for email: String) {
        let key = Self.normalize(email)
        guard data != icons[key] else { return }

        let storageKey = Self.storageKey(for: key)
        if let data {
            icons[key] = data
            defaults.set(data, forKey: storageKey)
            cloud.set(data, forKey: storageKey)
        } else {
            icons.removeValue(forKey: key)
            defaults.removeObject(forKey: storageKey)
            cloud.removeObject(forKey: storageKey)
        }
        cloud.synchronize()

        NotificationCenter.default.post(name: .accountIconsChanged, object: email)
    }

    func start() {
        guard cloudObserver == nil else { return }
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] notification in
            let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            self?.applyCloudChanges(forKeys: keys)
        }
        cloud.synchronize()
        // The initial value was already merged in `init`. Nothing here reads
        // the cloud wholesale, so a missing entitlement can't wipe the mirror.
    }

    /// The cloud key for an account. Exposed so tests can seed the fake
    /// store the way another Mac would.
    static func storageKey(for email: String) -> String {
        keyPrefix + normalize(email)
    }

    // MARK: - Storage helpers

    /// Applies what another Mac wrote. Only the named keys move; an icon the
    /// notification doesn't mention stays as it is, even if the cloud has no
    /// copy of it yet.
    private func applyCloudChanges(forKeys keys: [String]?) {
        let changedKeys = keys ?? Self.iconKeys(in: cloud.dictionaryRepresentation)
        var changed = false

        for storageKey in changedKeys where storageKey.hasPrefix(Self.keyPrefix) {
            let email = String(storageKey.dropFirst(Self.keyPrefix.count))
            let value = cloud.data(forKey: storageKey)
            guard value != icons[email] else { continue }

            if let value {
                icons[email] = value
                defaults.set(value, forKey: storageKey)
            } else {
                icons.removeValue(forKey: email)
                defaults.removeObject(forKey: storageKey)
            }
            changed = true
        }

        if changed {
            NotificationCenter.default.post(name: .accountIconsChanged, object: nil)
        }
    }

    private func readMerged() -> [String: Data] {
        let local = Self.icons(in: defaults.dictionaryRepresentation())
        let remote = Self.icons(in: cloud.dictionaryRepresentation)
        return local.merging(remote) { _, new in new }
    }

    private static func iconKeys(in dictionary: [String: Any]) -> [String] {
        dictionary.keys.filter { $0.hasPrefix(keyPrefix) }
    }

    private static func icons(in dictionary: [String: Any]) -> [String: Data] {
        var result: [String: Data] = [:]
        for key in iconKeys(in: dictionary) {
            guard let data = dictionary[key] as? Data else { continue }
            result[String(key.dropFirst(keyPrefix.count))] = data
        }
        return result
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
