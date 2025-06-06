//
//  Account.swift
//  Mail Notifr
//
//  Created by James Chen on 2021/06/16.
//  Copyright © 2021 ashchan.com. All rights reserved.
//

import Foundation
import GTMAppAuth
import KeychainAccess
import AppAuth

enum AccountType: String, Codable, CaseIterable {
    case gmail
    case outlook
}

struct Account: Codable {
    var email: String
    var type: AccountType = .gmail
    var enabled = true
    // interval as minutes
    var checkInterval: Double = 30 {
        didSet {
            checkInterval = max(
                min(Double(Int(checkInterval)), 900),
                1
            )
        }
    }
    var notificationEnabled = true
    var notificationSound = ""
    var openInBrowser = Browser.safariIdentifier
    var newestMessageDate: Date?
}

extension Account: Identifiable, Hashable {
    var id: String {
        email
    }

    var baseUrl: String {
        switch type {
        case .gmail:
            return "https://mail.google.com/mail/b/\(email)"
        case .outlook:
            return "https://outlook.live.com/mail/0/inbox"
        }
    }

    var browser: Browser {
        Browser(identifier: openInBrowser)
    }

    var sound: Sound? {
        Sound(rawValue: notificationSound)
    }
}

extension Account {
    var keychain: Keychain {
        Keychain(service: "com.ashchan.GmailNotifr")
    }

    var authorization: GTMAppAuthFetcherAuthorization? {
        get {
            if let data = keychain[data: id] {
                return try? NSKeyedUnarchiver.unarchivedObject(ofClass: GTMAppAuthFetcherAuthorization.self, from: data)
            }
            return nil
        }
        set {
            guard let newValue = newValue, newValue.canAuthorize() else {
                keychain[id] = nil
                return
            }
            let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
            keychain[data: id] = data
        }
    }

    var authState: OIDAuthState? {
        get {
            if let data = keychain[data: "\(id)-oid"] {
                return try? NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
            }
            return nil
        }
        set {
            guard let newValue = newValue else {
                keychain["\(id)-oid"] = nil
                return
            }
            let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
            keychain[data: "\(id)-oid"] = data
        }
    }
}

// MARK: - Allow persisting accounts to @AppStorage

struct Accounts: RawRepresentable, Codable, RandomAccessCollection, MutableCollection, ExpressibleByArrayLiteral {
    private var storage: [Account]

    init(_ accounts: [Account] = []) {
        self.storage = accounts
    }

    init(arrayLiteral elements: Account...) {
        self.storage = elements
    }

    // Collection
    typealias Index = Int
    var startIndex: Int { storage.startIndex }
    var endIndex: Int { storage.endIndex }
    func index(after i: Int) -> Int { storage.index(after: i) }
    subscript(position: Int) -> Account {
        get { storage[position] }
        set { storage[position] = newValue }
    }

    // RawRepresentable
    static let storageKey = "accounts"

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Account].self, from: data)
        else {
            return nil
        }
        self.storage = result
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(storage),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }

    // Helpers to mimic array behaviour
    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }

    mutating func append(_ element: Account) { storage.append(element) }
    @discardableResult mutating func remove(at index: Int) -> Account { storage.remove(at: index) }
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) { storage.move(fromOffsets: source, toOffset: destination) }
}

extension Notification.Name {
    static let accountAdded = Notification.Name("accountAdded")
    static let accountDeleted = Notification.Name("accountDeleted")
    static let accountUpdated = Notification.Name("accountUpdated")
    static let accountsReordered = Notification.Name("accountsReordered")
}

extension Accounts {

    static var `default`: Accounts {
        get {
            Accounts(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "[]") ?? []
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    static var hasAccounts: Bool {
        !Self.default.isEmpty
    }
}

extension Accounts {
    var enabled: Accounts {
        filter { $0.enabled }
    }

    func find(email: String) -> Account? {
        first { $0.email == email }
    }

    static func needsImmediateFetching(oldValue: Account, newValue: Account) -> Bool {
        newValue.enabled && !oldValue.enabled
    }

    static func needsReschduling(oldValue: Account, newValue: Account) -> Bool {
        newValue.checkInterval != oldValue.checkInterval
    }

    mutating func save() {
        Self.default = self
    }

    mutating func add(account: Account) {
        if firstIndex(where: { $0.id == account.id }) != nil {
            return
        }
        append(account)
        save()
        NotificationCenter.default.post(name: .accountAdded, object: account)
    }

    mutating func delete(account: Account) {
        guard let index = firstIndex(where: { $0.id == account.id }) else {
            return
        }
        self[index].authorization = nil
        remove(at: index)
        save()
        NotificationCenter.default.post(name: .accountDeleted, object: account)
    }

    mutating func update(account: Account) {
        guard let index = firstIndex(where: { $0.id == account.id }) else {
            return
        }
        let needsRescheduling = Self.needsReschduling(oldValue: self[index], newValue: account)
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

    static func authorize(type: AccountType) {
        switch type {
        case .gmail:
            OAuthClient.shared.authorize() { state in
                switch state {
                case .success(let state):
                    let authorization = GTMAppAuthFetcherAuthorization(authState: state)
                    if var account = Self.default.find(email: authorization.userEmail!) {
                        account.authorization = authorization
                        var accounts = Self.default
                        accounts.update(account: account)
                    } else {
                    var account = Account(email: authorization.userEmail!, type: .gmail)
                        account.authorization = authorization
                        var accounts = Self.default
                        accounts.add(account: account)
                    }
                case .failure(let error):
                    print(error)
                }
            }
        case .outlook:
            OutlookOAuthClient.shared.authorize { result in
                switch result {
                case .success(let state):
                    if var account = Self.default.find(email: state.lastTokenResponse?.additionalParameters?["preferred_username"] as? String ?? "") {
                        account.authState = state
                        var accounts = Self.default
                        accounts.update(account: account)
                    } else if let email = state.lastTokenResponse?.additionalParameters?["preferred_username"] as? String {
                        var account = Account(email: email, type: .outlook)
                        account.authState = state
                        var accounts = Self.default
                        accounts.add(account: account)
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
}
