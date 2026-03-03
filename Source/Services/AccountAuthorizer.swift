//
//  AccountAuthorizer.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import GTMAppAuth
import KeychainAccess
import AppAuth

// MARK: - Keychain Credential Storage

extension Account {
    var keychain: Keychain {
        Keychain(service: "com.strategicnerds.MailNotifierApp")
    }

    var authorization: GTMAppAuthFetcherAuthorization? {
        get {
            guard let data = keychain[data: id] else { return nil }
            do {
                return try NSKeyedUnarchiver.unarchivedObject(ofClass: GTMAppAuthFetcherAuthorization.self, from: data)
            } catch {
                Log.keychain.error("Failed to unarchive authorization for \(id): \(error.localizedDescription)")
                return nil
            }
        }
        set {
            let accountId = id
            guard let newValue, newValue.canAuthorize() else {
                keychain[accountId] = nil
                return
            }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
                keychain[data: accountId] = data
            } catch {
                Log.keychain.error("Failed to archive authorization for \(accountId): \(error.localizedDescription)")
            }
        }
    }

    var authState: OIDAuthState? {
        get {
            let keychainKey = "\(id)-oid"
            guard let data = keychain[data: keychainKey] else { return nil }
            do {
                return try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
            } catch {
                Log.keychain.error("Failed to unarchive auth state for \(keychainKey): \(error.localizedDescription)")
                return nil
            }
        }
        set {
            let accountId = id
            let keychainKey = "\(accountId)-oid"
            guard let newValue else {
                keychain[keychainKey] = nil
                return
            }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
                keychain[data: keychainKey] = data
            } catch {
                Log.keychain.error("Failed to archive auth state for \(keychainKey): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - OAuth Authorization Flows

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
