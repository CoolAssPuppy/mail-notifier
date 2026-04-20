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
            clientSecret: nil,
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
