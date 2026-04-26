//
//  AccountAuthorizer.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import AppKit
import GTMAppAuth
import KeychainAccess
import AppAuth

// MARK: - Keychain Credential Storage

extension Account {
    var keychain: Keychain {
        Keychain(service: "com.strategicnerds.MailNotifierApp")
            .accessibility(.whenUnlockedThisDeviceOnly)
    }

    var authorization: GTMAppAuthFetcherAuthorization? {
        get {
            guard let data = keychain[data: id] else { return nil }
            do {
                return try NSKeyedUnarchiver.unarchivedObject(ofClass: GTMAppAuthFetcherAuthorization.self, from: data)
            } catch {
                Log.keychain.error("Failed to unarchive authorization for account \(self.maskedAccountID, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
                let masked = maskedAccountID
                Log.keychain.error("Failed to archive authorization for account \(masked, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
                Log.keychain.error("Failed to unarchive auth state for account \(self.maskedAccountID, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
                let masked = maskedAccountID
                Log.keychain.error("Failed to archive auth state for account \(masked, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private var maskedAccountID: String {
        let lower = id.lowercased()
        if let at = lower.firstIndex(of: "@") {
            let domain = lower[at...]
            return "***\(domain)"
        }
        return "***"
    }
}

// MARK: - OAuth Authorization Flows

extension Accounts {
    /// Starts the OAuth flow for `type`. Looks up `NSApp.keyWindow` so the
    /// AppAuth-driven `ASWebAuthenticationSession` can present its sheet
    /// attached to the app rather than spawning the user's default browser.
    /// Falls back to the browser flow when no window is key (very early
    /// app launch, no UI on screen yet).
    static func authorize(type: AccountType) {
        let window = NSApp.keyWindow
        switch type {
        case .gmail:
            GoogleOAuthClient.shared.authorize(presentingWindow: window) { result in
                guard case .success(let state) = result else {
                    Telemetry.capture("account.signin_failed", properties: ["provider": "gmail"])
                    return
                }
                let authorization = GTMAppAuthFetcherAuthorization(authState: state)
                guard let userEmail = authorization.userEmail else {
                    Telemetry.capture("account.signin_failed", properties: ["provider": "gmail", "reason": "no_email"])
                    return
                }

                var accounts = Self.default
                if var account = accounts.find(email: userEmail) {
                    account.authorization = authorization
                    accounts.update(account: account)
                } else {
                    var account = Account(email: userEmail, type: .gmail)
                    account.authorization = authorization
                    accounts.add(account: account)
                    Telemetry.capture("account.added", properties: ["provider": "gmail"])
                }
            }

        case .outlook:
            OutlookOAuthClient.shared.authorize(presentingWindow: window) { result in
                guard case .success(let state) = result else {
                    Telemetry.capture("account.signin_failed", properties: ["provider": "outlook"])
                    return
                }
                fetchOutlookEmail(for: state) { email in
                    guard let email else {
                        Telemetry.capture("account.signin_failed", properties: ["provider": "outlook", "reason": "no_email"])
                        return
                    }

                    var accounts = Self.default
                    if var account = accounts.find(email: email) {
                        account.authState = state
                        accounts.update(account: account)
                    } else {
                        var account = Account(email: email, type: .outlook)
                        account.authState = state
                        accounts.add(account: account)
                        Telemetry.capture("account.added", properties: ["provider": "outlook"])
                    }
                }
            }
        }
    }

    private static func fetchOutlookEmail(for state: OIDAuthState, completion: @escaping (String?) -> Void) {
        state.performAction { accessToken, _, error in
            if let error {
                Log.auth.error("Failed to fetch Outlook access token for profile lookup: \(error.localizedDescription, privacy: .public)")
                completion(nil)
                return
            }

            guard let accessToken else {
                completion(nil)
                return
            }

            guard let url = URL(string: "https://graph.microsoft.com/v1.0/me?$select=mail,userPrincipalName") else {
                completion(nil)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    Log.network.error("Outlook profile lookup failed: \(error.localizedDescription, privacy: .public)")
                    completion(nil)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let data else {
                    completion(nil)
                    return
                }

                struct OutlookMeResponse: Decodable {
                    let mail: String?
                    let userPrincipalName: String?
                }

                let profile = try? JSONDecoder().decode(OutlookMeResponse.self, from: data)
                let email = profile?.mail?.nonEmpty ?? profile?.userPrincipalName?.nonEmpty
                completion(email?.lowercased())
            }.resume()
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
