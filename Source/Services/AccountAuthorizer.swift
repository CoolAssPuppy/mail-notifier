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
        Log.auth.info("Starting OAuth flow for \(type.rawValue, privacy: .public). presentingWindow=\(window == nil ? "nil (browser fallback)" : "set (ASWebAuthenticationSession)", privacy: .public)")
        switch type {
        case .gmail:
            GoogleOAuthClient.shared.authorize(presentingWindow: window) { result in
                switch result {
                case .failure(let error):
                    Log.auth.error("Gmail OAuth failed: \(String(describing: error), privacy: .public)")
                    Telemetry.capture("account.signin_failed", properties: ["provider": "gmail"])
                    return
                case .success(let state):
                    let authorization = GTMAppAuthFetcherAuthorization(authState: state)
                    guard let userEmail = authorization.userEmail else {
                        Log.auth.error("Gmail OAuth succeeded but state contained no userEmail")
                        Telemetry.capture("account.signin_failed", properties: ["provider": "gmail", "reason": "no_email"])
                        return
                    }

                    Log.auth.info("Gmail OAuth completed for \(userEmail, privacy: .private)")
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
            }

        case .outlook:
            OutlookOAuthClient.shared.authorize(presentingWindow: window) { result in
                switch result {
                case .failure(let error):
                    Log.auth.error("Outlook OAuth failed: \(String(describing: error), privacy: .public)")
                    Telemetry.capture("account.signin_failed", properties: ["provider": "outlook"])
                    return
                case .success(let state):
                    Log.auth.info("Outlook OAuth state received (token issued at: \(state.lastTokenResponse?.accessTokenExpirationDate.map { String(describing: $0) } ?? "nil", privacy: .public))")
                    guard let email = outlookEmailFromIDToken(state) else {
                        Log.auth.error("Outlook OAuth succeeded but ID token had no email/preferred_username claim")
                        Telemetry.capture("account.signin_failed", properties: ["provider": "outlook", "reason": "no_email"])
                        return
                    }

                    Log.auth.info("Outlook OAuth completed for \(email, privacy: .private)")
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

    /// Reads the user's email from the OIDC ID token claims instead of
    /// calling Microsoft Graph `/me`. Graph requires `User.Read` scope which
    /// we don't request — Microsoft tightened this and now returns 403 when
    /// the token only carries `openid + profile + email + Mail.Read`. The
    /// ID token already has the email we need (granted by the `email`
    /// scope), so this avoids the Graph call entirely and works for both
    /// personal Microsoft accounts (Hotmail/Outlook.com) and work/school.
    private static func outlookEmailFromIDToken(_ state: OIDAuthState) -> String? {
        guard let idToken = state.lastTokenResponse?.idToken else {
            Log.auth.error("Outlook auth state has no ID token — was the openid scope granted?")
            return nil
        }
        guard let claims = decodeJWTClaims(idToken) else {
            Log.auth.error("Failed to decode Outlook ID token payload")
            return nil
        }

        let email = (claims["email"] as? String)?.nonEmpty
            ?? (claims["preferred_username"] as? String)?.nonEmpty
            ?? (claims["upn"] as? String)?.nonEmpty
        if email == nil {
            let presentClaims = claims.keys.sorted().joined(separator: ",")
            Log.auth.error("Outlook ID token had no email/preferred_username/upn claim. Claims present: \(presentClaims, privacy: .public)")
        }
        return email?.lowercased()
    }

    private static func decodeJWTClaims(_ jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }
        let payload = segments[1]
        // base64url -> base64 (swap chars and pad to multiple of 4)
        var b64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - b64.count % 4) % 4
        b64.append(String(repeating: "=", count: pad))

        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
