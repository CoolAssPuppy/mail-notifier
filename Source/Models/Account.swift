//
//  Account.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
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
    var checkInterval: Double = 30 {
        didSet {
            checkInterval = max(min(Double(Int(checkInterval)), 900), 1)
        }
    }
    var notificationEnabled = true
    var notificationSound = ""
    var openInBrowser = Browser.safariIdentifier
    var newestMessageDate: Date?
}

extension Account: Identifiable, Hashable {
    var id: String { email }

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
        Keychain(service: "com.strategicnerds.MailNotifierApp")
    }

    var authorization: GTMAppAuthFetcherAuthorization? {
        get {
            guard let data = keychain[data: id] else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: GTMAppAuthFetcherAuthorization.self, from: data)
        }
        set {
            guard let newValue, newValue.canAuthorize() else {
                keychain[id] = nil
                return
            }
            let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
            keychain[data: id] = data
        }
    }

    var authState: OIDAuthState? {
        get {
            let keychainKey = "\(id)-oid"
            guard let data = keychain[data: keychainKey] else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
        }
        set {
            let keychainKey = "\(id)-oid"
            guard let newValue else {
                keychain[keychainKey] = nil
                return
            }
            let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
            keychain[data: keychainKey] = data
        }
    }
}

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

    static func needsReschduling(oldValue: Account, newValue: Account) -> Bool {
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
}

// MARK: - OAuth Authorization

extension Accounts {
    static func authorize(type: AccountType) {
        switch type {
        case .gmail:
            GoogleOAuthClient.shared.authorize { result in
                guard case .success(let state) = result else { return }
                let authorization = GTMAppAuthFetcherAuthorization(authState: state)
                guard let userEmail = authorization.userEmail else { return }

                var accounts = Self.default
                if var account = accounts.find(email: userEmail) {
                    account.authorization = authorization
                    accounts.update(account: account)
                } else {
                    var account = Account(email: userEmail, type: .gmail)
                    account.authorization = authorization
                    accounts.add(account: account)
                }
            }

        case .outlook:
            OutlookOAuthClient.shared.authorize { result in
                guard case .success(let state) = result else { return }

                // Extract email from token response
                var email: String?
                if let params = state.lastTokenResponse?.additionalParameters {
                    email = params["preferred_username"] as? String
                        ?? params["email"] as? String
                        ?? params["upn"] as? String
                }

                // Try ID token claims if not found
                if email == nil, let idToken = state.lastTokenResponse?.idToken,
                   let claims = decodeJWT(idToken) {
                    email = claims["preferred_username"] as? String
                        ?? claims["email"] as? String
                        ?? claims["upn"] as? String
                }

                guard let email else { return }

                var accounts = Self.default
                if var account = accounts.find(email: email) {
                    account.authState = state
                    accounts.update(account: account)
                } else {
                    var account = Account(email: email, type: .outlook)
                    account.authState = state
                    accounts.add(account: account)
                }
            }
        }
    }

    private static func decodeJWT(_ jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }

        var base64String = segments[1]
        let remainder = base64String.count % 4
        if remainder > 0 {
            base64String = base64String.padding(toLength: base64String.count + 4 - remainder, withPad: "=", startingAt: 0)
        }

        guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }

        return json
    }
}
