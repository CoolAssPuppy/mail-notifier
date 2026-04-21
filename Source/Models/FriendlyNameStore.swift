//
//  FriendlyNameStore.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import Combine

/// Keyed map of account email → user-chosen friendly name (e.g. "Work", "Supabase").
///
/// Backed by `NSUbiquitousKeyValueStore` so names roam across machines signed
/// into the same Apple ID, with a `UserDefaults` mirror so reads are fast and
/// the feature still works when iCloud is unavailable.
///
/// Views observe `shared` as an `@ObservedObject` to refresh when names
/// change locally or arrive from the cloud.
final class FriendlyNameStore: ObservableObject {
    static let shared = FriendlyNameStore()

    @Published private(set) var names: [String: String] = [:]

    private static let kvsKey = "friendlyNames"
    private static let defaultsKey = "friendlyNames"

    private let kvs = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var kvsObserver: NSObjectProtocol?

    private init() {
        names = readMerged()
    }

    // MARK: - Public API

    func name(for email: String) -> String? {
        names[normalize(email)]
    }

    func setName(_ name: String?, for email: String) {
        let key = normalize(email)
        let trimmed = name?.trimmed.nonEmpty
        guard trimmed != names[key] else { return }

        if let trimmed {
            names[key] = trimmed
        } else {
            names.removeValue(forKey: key)
        }

        defaults.set(names, forKey: Self.defaultsKey)
        kvs.set(names, forKey: Self.kvsKey)
        kvs.synchronize()

        NotificationCenter.default.post(name: .friendlyNamesChanged, object: email)
    }

    func remove(email: String) {
        setName(nil, for: email)
    }

    func start() {
        guard kvsObserver == nil else { return }
        kvsObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs,
            queue: .main
        ) { [weak self] _ in
            self?.syncFromCloud()
        }
        kvs.synchronize()
        syncFromCloud()
    }

    deinit {
        if let kvsObserver {
            NotificationCenter.default.removeObserver(kvsObserver)
        }
    }

    // MARK: - Storage helpers

    private func syncFromCloud() {
        let cloud = (kvs.dictionary(forKey: Self.kvsKey) as? [String: String]) ?? [:]
        guard cloud != names else { return }
        names = cloud
        defaults.set(cloud, forKey: Self.defaultsKey)
        NotificationCenter.default.post(name: .friendlyNamesChanged, object: nil)
    }

    private func readMerged() -> [String: String] {
        let cloud = (kvs.dictionary(forKey: Self.kvsKey) as? [String: String]) ?? [:]
        let local = defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
        return local.merging(cloud) { _, new in new }
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
