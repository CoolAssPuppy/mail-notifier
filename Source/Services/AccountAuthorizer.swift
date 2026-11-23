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
                    reportSigninFailure(SigninFailure(provider: .gmail, error: error))
                case .success(let state):
                    let authorization = GTMAppAuthFetcherAuthorization(authState: state)
                    guard let userEmail = authorization.userEmail else {
                        Log.auth.error("Gmail OAuth succeeded but state contained no userEmail")
                        reportSigninFailure(.missingEmail(provider: .gmail))
                        return
                    }
                    Log.auth.info("Gmail OAuth completed for \(userEmail, privacy: .private)")
                    finish(storeAuthorized(email: userEmail, type: .gmail) { account in
                        account.authorization = authorization
                    }, provider: "gmail")
                }
            }

        case .outlook:
            OutlookOAuthClient.shared.authorize(presentingWindow: window) { result in
                switch result {
                case .failure(let error):
                    Log.auth.error("Outlook OAuth failed: \(String(describing: error), privacy: .public)")
                    reportSigninFailure(SigninFailure(provider: .outlook, error: error))
                case .success(let state):
                    Log.auth.info("Outlook OAuth state received (token issued at: \(state.lastTokenResponse?.accessTokenExpirationDate.map { String(describing: $0) } ?? "nil", privacy: .public))")
                    guard let token = outlookIDToken(state), let email = token.email else {
                        Log.auth.error("Outlook OAuth succeeded but ID token had no email/preferred_username claim")
                        reportSigninFailure(.missingEmail(provider: .outlook))
                        return
                    }
                    Log.auth.info("Outlook OAuth completed for \(email, privacy: .private). Work or school account: \(token.isWorkOrSchool.map { String($0) } ?? "unknown", privacy: .public)")
                    finish(storeAuthorized(email: email, type: .outlook, tenantID: token.tenantID) { account in
                        account.authState = state
                    }, provider: "outlook")
                }
            }
        }
    }

    private static func finish(_ outcome: AuthorizedAccountOutcome, provider: String) {
        switch outcome {
        case .added:
            Telemetry.capture(.accountAdded, properties: ["provider": provider])
        case .reauthorized:
            break
        case .refused:
            refuseAdd(provider: provider)
        }
    }

    /// Records the failure with its domain, code and OAuth error string, and
    /// asks the main window to explain it unless the person cancelled.
    private static func reportSigninFailure(_ failure: SigninFailure) {
        Telemetry.capture(.accountSigninFailed, properties: failure.telemetryProperties)
        guard failure.shouldExplain else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .signinFailed, object: failure)
        }
    }

    // MARK: Subscription gate

    /// Whether another account may be created right now.
    ///
    /// This sits inside the OAuth success branch rather than only in front of
    /// the connect buttons, because this is the single function that turns a
    /// finished OAuth flow into a stored account. A gate here covers the two
    /// provider cards, the popover's add button, the classic menu's add item,
    /// and whatever entry point gets added next. Reauthorizing an account that
    /// already exists never reaches this check.
    static func canAddAccount() -> Bool {
        if EntitlementManager.isEntitledNow() { return true }
        return Self.default.enabled.count < Accounts.freeAccountLimit
    }

    /// Drops a completed-but-unpayable authorization and asks for the paywall.
    /// The OAuth tokens are simply never written, so nothing has to be cleaned
    /// up; the account was never created.
    private static func refuseAdd(provider: String) {
        Log.auth.info("Refusing to add a \(provider, privacy: .public) account: free account limit reached and no active subscription")
        Telemetry.capture(.paywallShown, properties: ["trigger": PaywallTrigger.addAccount.rawValue,
                                                      "provider": provider])
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .showPaywall, object: PaywallTrigger.addAccount)
        }
    }

    /// Reads the email and tenant from the OIDC ID token instead of calling
    /// Microsoft Graph `/me`, which needs `User.Read`. The `email` scope puts
    /// the address in the token for both personal and work or school accounts.
    private static func outlookIDToken(_ state: OIDAuthState) -> MicrosoftIDToken? {
        guard let idToken = state.lastTokenResponse?.idToken else {
            Log.auth.error("Outlook auth state has no ID token. Was the openid scope granted?")
            return nil
        }
        guard let token = MicrosoftIDToken(jwt: idToken) else {
            Log.auth.error("Failed to decode Outlook ID token payload")
            return nil
        }
        return token
    }
}
