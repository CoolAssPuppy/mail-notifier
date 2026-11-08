import Foundation

/// Keeps quiet-hour messages from appearing on a later fetch of the same inbox.
final class SuppressedNotificationStore {
    private let defaults: UserDefaults
    private let key: String
    private let limit: Int
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard,
         key: String = "notifications.quietHoursSuppressedIDs",
         limit: Int = 200) {
        self.defaults = defaults
        self.key = key
        self.limit = max(limit, 1)
    }

    func contains(_ identifier: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedIDs().contains(identifier)
    }

    func mark(_ identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }

        var ordered = storedIDs()
        var seen = Set(ordered)
        for identifier in identifiers where seen.insert(identifier).inserted {
            ordered.append(identifier)
        }
        defaults.set(Array(ordered.suffix(limit)), forKey: key)
    }

    private func storedIDs() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }
}
