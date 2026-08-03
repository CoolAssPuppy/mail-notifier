//
//  AccountStore.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

// MARK: - Accounts Collection

struct Accounts: RawRepresentable, Codable, RandomAccessCollection, MutableCollection, ExpressibleByArrayLiteral {
    private var storage: [Account]

    init(_ accounts: [Account] = []) {
        self.storage = accounts
    }

    init(arrayLiteral elements: Account...) {
        self.storage = elements
    }

    // Collection conformance
    typealias Index = Int
    var startIndex: Int { storage.startIndex }
    var endIndex: Int { storage.endIndex }
    func index(after i: Int) -> Int { storage.index(after: i) }

    subscript(position: Int) -> Account {
        get { storage[position] }
        set { storage[position] = newValue }
    }

    // RawRepresentable conformance
    static let storageKey = "accounts"

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Account].self, from: data) else {
            return nil
        }
        self.storage = result
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(storage),
              let result = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return result
    }

    // Array-like helpers
    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }

    mutating func append(_ element: Account) { storage.append(element) }
    @discardableResult mutating func remove(at index: Int) -> Account { storage.remove(at: index) }
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) { storage.move(fromOffsets: source, toOffset: destination) }
}

// MARK: - Static Accessors

extension Accounts {
    /// UserDefaults backing store. Tests inject a non-standard suite so they
    /// don't pollute the user's real preferences.
    static var defaults: UserDefaults = .standard

    static var `default`: Accounts {
        get { Accounts(rawValue: defaults.string(forKey: storageKey) ?? "[]") ?? [] }
        set { defaults.set(newValue.rawValue, forKey: storageKey) }
    }

    static var hasAccounts: Bool { !Self.default.isEmpty }
}

// MARK: - Subscription Gate

extension Accounts {
    /// How many accounts run without a subscription. Everything past this needs
    /// the paid plan. One number, one place, so changing the free tier is a
    /// one-line edit rather than a hunt through the gates.
    static let freeAccountLimit = 1

    /// Enabled accounts split into the ones that may run and the ones the
    /// subscription gates.
    ///
    /// The free slots go to the first enabled accounts in the stored order,
    /// which is the order the sidebar shows. "Use this one instead" on a locked
    /// account's banner moves it to the front, and that is how someone chooses
    /// which inbox stays free. The partition runs over *enabled* accounts on
    /// purpose: turning an account off shouldn't strand its free slot on
    /// something that isn't running.
    ///
    /// Pure and static so it tests without a store, a network, or a UI.
    static func partition(enabled accounts: [Account],
                          isEntitled: Bool,
                          limit: Int = freeAccountLimit) -> (active: [Account], locked: [Account]) {
        guard !isEntitled else { return (accounts, []) }
        // Qualified: `Accounts` is a Collection, so a bare `max` binds to the
        // instance method rather than the global function.
        let cut = Swift.max(0, limit)
        return (Array(accounts.prefix(cut)), Array(accounts.dropFirst(cut)))
    }

    /// Enabled accounts allowed to run under the current entitlement.
    static func active(isEntitled: Bool) -> [Account] {
        partition(enabled: Array(Self.default.enabled), isEntitled: isEntitled).active
    }

    /// Enabled accounts the subscription is holding back. Empty when entitled.
    static func locked(isEntitled: Bool) -> [Account] {
        partition(enabled: Array(Self.default.enabled), isEntitled: isEntitled).locked
    }
}

// MARK: - Account Management

extension Accounts {
    var enabled: Accounts {
        Accounts(filter { $0.enabled })
    }

    func find(email: String) -> Account? {
        first { $0.email == email }
    }

    static func needsImmediateFetching(oldValue: Account, newValue: Account) -> Bool {
        newValue.enabled && !oldValue.enabled
    }

    static func needsRescheduling(oldValue: Account, newValue: Account) -> Bool {
        newValue.checkInterval != oldValue.checkInterval
    }

    mutating func save() {
        Self.default = self
    }

    mutating func add(account: Account) {
        guard firstIndex(where: { $0.id == account.id }) == nil else { return }
        append(account)
        save()
        NotificationCenter.default.post(name: .accountAdded, object: account)
    }

    mutating func delete(account: Account) {
        guard let index = firstIndex(where: { $0.id == account.id }) else { return }
        self[index].authorization = nil
        self[index].authState = nil
        remove(at: index)
        save()
        NotificationCenter.default.post(name: .accountDeleted, object: account)
    }

    mutating func update(account: Account) {
        guard let index = firstIndex(where: { $0.id == account.id }) else { return }
        let needsRescheduling = Self.needsRescheduling(oldValue: self[index], newValue: account)
        let needsImmediateFetching = Self.needsImmediateFetching(oldValue: self[index], newValue: account)
        self[index] = account
        save()
        NotificationCenter.default.post(
            name: .accountUpdated,
            object: account,
            userInfo: ["needsRescheduling": needsRescheduling, "needsImmediateFetching": needsImmediateFetching]
        )
    }

    mutating func reorder(fromOffsets source: IndexSet, toOffset destination: Int) {
        move(fromOffsets: source, toOffset: destination)
        save()
        NotificationCenter.default.post(name: .accountsReordered, object: nil)
    }
}
