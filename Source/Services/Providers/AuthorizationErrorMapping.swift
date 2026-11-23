//
//  AuthorizationErrorMapping.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation
import AppAuth

extension MailProviderError {
    /// True when `error`, or an error it wraps, says the stored authorization
    /// is no longer good and only a new sign-in will fix it: the token
    /// endpoint refused the refresh token (`invalid_grant` for a revoked or
    /// expired grant), or AppAuth had no refresh token to use.
    ///
    /// A refresh that failed for lack of a connection stays a network error.
    static func requiresSignIn(_ error: Error) -> Bool {
        var current: NSError? = error as NSError
        var depth = 0
        while let nsError = current, depth < 4 {
            if nsError.domain == OIDOAuthTokenErrorDomain { return true }
            if nsError.domain == OIDGeneralErrorDomain,
               nsError.code == OIDErrorCode.tokenRefreshError.rawValue {
                return true
            }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return false
    }
}

extension OutlookProvider {
    /// Maps an error from `OIDAuthState.performAction`, which is where a
    /// refresh failure surfaces.
    static func mapAuthorizationError(_ error: Error) -> MailProviderError {
        MailProviderError.requiresSignIn(error) ? .authenticationRequired : .networkError(error)
    }
}
