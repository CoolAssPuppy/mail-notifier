//
//  AccountAuthorizer.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import AppKit
import GTMAppAuth
#if !MAC_APP_STORE
import KeychainAccess
#endif
import AppAuth

// MARK: - Keychain Credential Storage

extension Account {
    #if !MAC_APP_STORE
    private var keychain: Keychain {
        Keychain(service: "com.strategicnerds.MailNotifierApp")
            .accessibility(.whenUnlockedThisDeviceOnly)
    }
    #endif

    var authorization: GTMAppAuthFetcherAuthorization? {
        get { credential(GTMAppAuthFetcherAuthorization.self, key: id) }
        set { try? writeCredential(newValue?.canAuthorize() == true ? newValue : nil, key: id) }
    }

    var authState: OIDAuthState? {
        get { credential(OIDAuthState.self, key: "\(id)-oid") }
        set { try? writeCredential(newValue, key: "\(id)-oid") }
    }

    fileprivate func writeCredential(_ value: NSSecureCoding?, key: String) throws {
        do {
            if let value {
                let data = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
                #if MAC_APP_STORE
                try StoreCredentialKeychain.set(data, for: key)
                #else
                try keychain.set(data, key: key)
                #endif
            } else {
                #if MAC_APP_STORE
                try StoreCredentialKeychain.remove(key)
                #else
                try keychain.remove(key)
                #endif
            }
        } catch {
            Log.keychain.error("Failed to write credentials for \(self.maskedAccountID, privacy: .public): \((error as NSError).code, privacy: .public)")
            throw error
        }
    }

    private func credential<T: NSObject & NSSecureCoding>(_ type: T.Type, key: String) -> T? {
        do {
            #if MAC_APP_STORE
            let data = try StoreCredentialKeychain.data(for: key)
            #else
            let data = try keychain.getData(key)
            #endif
            guard let data else { return nil }
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: type, from: data)
        } catch {
            Log.keychain.error("Failed to read credentials for \(self.maskedAccountID, privacy: .public): \((error as NSError).code, privacy: .public)")
            return nil
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
        guard !DemoMode.isOnNow else { return }
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
                    guard let userEmail = authorization.userEmail, authorization.canAuthorize() else {
                        Log.auth.error("Gmail OAuth state did not contain an authorized account")
                        reportSigninFailure(.missingEmail(provider: .gmail))
                        return
                    }
                    Log.auth.info("Gmail OAuth completed for \(userEmail, privacy: .private)")
                    finishSignIn(email: userEmail, type: .gmail) { account in
                        try account.writeCredential(authorization, key: account.id)
                    }
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
                    finishSignIn(email: email, type: .outlook, tenantID: token.tenantID) { account in
                        try account.writeCredential(state, key: "\(account.id)-oid")
                    }
                }
            }
        }
    }

    private static func finishSignIn(email: String, type: AccountType, tenantID: String? = nil,
                                     save: (inout Account) throws -> Void) {
        let outcome: AuthorizedAccountOutcome
        do {
            outcome = try storeAuthorized(email: email, type: type, tenantID: tenantID, applyCredentials: save)
        } catch {
            reportSigninFailure(.credentialStorage(provider: type))
            return
        }
        let provider = type.rawValue
        switch outcome {
        case .added:
            Telemetry.capture(.accountAdded, properties: ["provider": provider])
        case .reauthorized:
            break
        case .refused:
            #if !MAC_APP_STORE
            refuseAdd(provider: provider)
            #else
            break // Demo Mode was enabled while authorization was in flight.
            #endif
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
        #if MAC_APP_STORE
        return true
        #else
        if EntitlementManager.isEntitledNow() { return true }
        return Self.default.enabled.count < Accounts.freeAccountLimit
        #endif
    }

    /// Drops a completed-but-unpayable authorization and asks for the paywall.
    /// The OAuth tokens are simply never written, so nothing has to be cleaned
    /// up; the account was never created.
    #if !MAC_APP_STORE
    private static func refuseAdd(provider: String) {
        Log.auth.info("Refusing to connect a \(provider, privacy: .public) account: no available account slot")
        Telemetry.capture(.paywallShown, properties: ["trigger": PaywallTrigger.addAccount.rawValue,
                                                      "provider": provider])
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .showPaywall, object: PaywallTrigger.addAccount)
        }
    }
    #endif

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
