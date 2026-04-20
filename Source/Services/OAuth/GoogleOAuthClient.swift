//
//  GoogleOAuthClient.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppAuth
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

    func authorize(_ authorized: @escaping (Result<OIDAuthState, Error>) -> Void) {
        let request = OIDAuthorizationRequest(
            configuration: GTMAppAuthFetcherAuthorization.configurationForGoogle(),
            clientId: Self.clientID,
            clientSecret: Self.clientSecret,
            scopes: [OIDScopeEmail, "https://www.googleapis.com/auth/gmail.readonly"],
            redirectURL: URL(string: Self.redirectURL)!,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )
        Self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { state, error in
            if let state = state {
                authorized(.success(state))
            } else {
                authorized(.failure(error ?? AuthError(message: "Auth with Google failed.")))
            }
        }
    }

    struct AuthError: LocalizedError {
        var message: String
    }
}
