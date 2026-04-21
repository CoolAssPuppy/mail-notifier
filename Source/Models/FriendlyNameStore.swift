//
//  FriendlyNameStore.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

/// Keyed map of account email → user-chosen friendly name (e.g. "Work", "Supabase").
///
/// The store is backed by `NSUbiquitousKeyValueStore` so names roam across machines
/// signed into the same Apple ID. A mirror is kept in `UserDefaults` so reads never
/// block on iCloud availability and the feature still works when iCloud is off.
///
/// Posts `.friendlyNamesChanged` whenever values change (local or remote).
enum FriendlyNameStore {
    private static let kvsKey = "friendlyNames"
    private static let defaultsKey = "friendlyNames"

    private static let kvs = NSUbiquitousKeyValueStore.default
    private static let defaults = UserDefaults.standard

    // MARK: - Public API

    static func name(for email: String) -> String? {
        let key = normalize(email)
        let merged = readMerged()
        return merged[key]?.trimmed.nonEmpty
    }

    static func setName(_ name: String?, for email: String) {
        let key = normalize(email)
        var merged = readMerged()

        if let trimmed = name?.trimmed.nonEmpty {
            merged[key] = trimmed
        } else {
            merged.removeValue(forKey: key)
        }

        write(merged)
        NotificationCenter.default.post(name: .friendlyNamesChanged, object: email)
    }

    static func remove(email: String) {
        setName(nil, for: email)
    }

    static func start() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs,
            queue: .main
        ) { _ in
            mirrorFromKVSToDefaults()
            NotificationCenter.default.post(name: .friendlyNamesChanged, object: nil)
        }
        kvs.synchronize()
        mirrorFromKVSToDefaults()
    }

    // MARK: - Storage helpers

    private static func readMerged() -> [String: String] {
        let cloud = (kvs.dictionary(forKey: kvsKey) as? [String: String]) ?? [:]
        let local = defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        return local.merging(cloud) { _, new in new }
    }

    private static func write(_ map: [String: String]) {
        defaults.set(map, forKey: defaultsKey)
        kvs.set(map, forKey: kvsKey)
        kvs.synchronize()
    }

    private static func mirrorFromKVSToDefaults() {
        guard let cloud = kvs.dictionary(forKey: kvsKey) as? [String: String] else { return }
        defaults.set(cloud, forKey: defaultsKey)
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension Notification.Name {
    static let friendlyNamesChanged = Notification.Name("friendlyNamesChanged")
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
