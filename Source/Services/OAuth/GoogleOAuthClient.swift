//
//  GoogleOAuthClient.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppAuth
import AppKit
import GTMAppAuth

struct GoogleOAuthClient {
    private init() {}
    static let shared = GoogleOAuthClient()

    static var clientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
    }

    // Google OAuth clients of the "iOS application" type issue a client_secret
    // that the token endpoint validates on every code -> token exchange. The
    // secret is intentionally bundled with the app (it isn't cryptographically
    // secret — PKCE is what secures the flow) and leaving it nil causes Google
    // to reject token exchange with invalid_client, so the redirect arrives
    // but the account never gets created.
    static var clientSecret: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "GoogleClientSecret") as? String ?? ""
        return value.isEmpty ? nil : value
    }

    static var redirectURL: String {
        "com.googleusercontent.apps.\(clientID.components(separatedBy: ".").first ?? ""):/oauthredirect"
    }

    static var redirectScheme: String {
        redirectURL.components(separatedBy: ":").first ?? ""
    }

    static var currentAuthorizationFlow: OIDExternalUserAgentSession?

    func resumeAuthFlow(url: URL) {
        if let currentFlow = Self.currentAuthorizationFlow, currentFlow.resumeExternalUserAgentFlow(with: url) {
            Self.currentAuthorizationFlow = nil
        }
    }

    /// Starts the Google OAuth flow.
    /// - Parameter presentingWindow: When non-nil, AppAuth uses
    ///   `ASWebAuthenticationSession` to present the auth UI as a sheet
    ///   attached to this window — same shape as Apple's "Sign in with…"
    ///   flow. When nil, the deprecated default-browser flow runs as a
    ///   fallback so callers without a window context still work.
    func authorize(presentingWindow: NSWindow?,
                   _ authorized: @escaping (Result<OIDAuthState, Error>) -> Void) {
        guard !Self.clientID.isEmpty else {
            authorized(.failure(AuthError(message: "Google Client ID is missing.")))
            return
        }
        guard let redirectURL = URL(string: Self.redirectURL) else {
            authorized(.failure(AuthError(message: "Google redirect URL is invalid.")))
            return
        }

        let request = OIDAuthorizationRequest(
            configuration: GTMAppAuthFetcherAuthorization.configurationForGoogle(),
            clientId: Self.clientID,
            clientSecret: Self.clientSecret,
            scopes: [OIDScopeEmail, "https://www.googleapis.com/auth/gmail.readonly"],
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )

        let callback: (OIDAuthState?, Error?) -> Void = { state, error in
            if let state {
                authorized(.success(state))
            } else {
                authorized(.failure(error ?? AuthError(message: "Auth with Google failed.")))
            }
        }

        if let presentingWindow {
            Self.currentAuthorizationFlow = OIDAuthState.authState(
                byPresenting: request,
                presenting: presentingWindow,
                callback: callback
            )
        } else {
            Self.currentAuthorizationFlow = OIDAuthState.authState(
                byPresenting: request,
                callback: callback
            )
        }
    }

    struct AuthError: LocalizedError {
        var message: String
    }
}
