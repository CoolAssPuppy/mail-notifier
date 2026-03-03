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
    static var `default`: Accounts {
        get { Accounts(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "[]") ?? [] }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }

    static var hasAccounts: Bool { !Self.default.isEmpty }
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
