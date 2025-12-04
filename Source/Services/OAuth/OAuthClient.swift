//
//  OAuthClient.swift
//  Mail Notifier
//

//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppAuth
import GTMAppAuth

struct OAuthClient {
    private init() {}
    static let shared = OAuthClient()

    static let clientID = "191228481940-3kikm89l8pgjn7rsvhbra3jqvtt5f479.apps.googleusercontent.com"
    static let clientSecret = OAuthSecret.secret  // You'll need to add your client secret here
    static let redirectURL = "com.googleusercontent.apps.191228481940-3kikm89l8pgjn7rsvhbra3jqvtt5f479:/oauthredirect"
    
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
