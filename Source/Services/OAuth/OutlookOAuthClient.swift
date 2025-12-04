//
//  OutlookOAuthClient.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import AppKit
import AppAuth

struct OutlookOAuthClient {
    private init() {}
    static let shared = OutlookOAuthClient()

    static let clientID = "a325ea11-cc04-4062-b65e-8418044ab444"
    static let clientSecret = OutlookOAuthSecret.secret
    static let redirectURL = "msala325ea11-cc04-4062-b65e-8418044ab444://auth/"

    static var currentAuthorizationFlow: OIDExternalUserAgentSession?

    func resumeAuthFlow(url: URL) {
        guard let currentFlow = Self.currentAuthorizationFlow else { return }
        if currentFlow.resumeExternalUserAgentFlow(with: url) {
            Self.currentAuthorizationFlow = nil
        }
    }

    func authorize(_ completion: @escaping (Result<OIDAuthState, Error>) -> Void) {
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
        )

        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: Self.clientID,
            clientSecret: nil,
            scopes: [
                "openid",
                "profile",
                "email",
                "offline_access",
                "https://graph.microsoft.com/Mail.Read"
            ],
            redirectURL: URL(string: Self.redirectURL)!,
            responseType: OIDResponseTypeCode,
            additionalParameters: ["prompt": "select_account"]
        )

        Self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { state, error in
            if let state {
                completion(.success(state))
            } else {
                completion(.failure(error ?? NSError(domain: "OutlookAuth", code: -1, userInfo: nil)))
            }
        }
    }
}
