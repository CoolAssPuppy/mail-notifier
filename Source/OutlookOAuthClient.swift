import Foundation
import AppKit
import AppAuth

struct OutlookOAuthClient {
    private init() {}
    static let shared = OutlookOAuthClient()

    // Replace with your own Azure app credentials
    static let clientID = "a325ea11-cc04-4062-b65e-8418044ab444"
    static let clientSecret = OutlookOAuthSecret.secret
    static let redirectURL = "msala325ea11-cc04-4062-b65e-8418044ab444://auth/"

    static var currentAuthorizationFlow: OIDExternalUserAgentSession?

    func resumeAuthFlow(url: URL) {
        print("🔄 OutlookOAuthClient.resumeAuthFlow called with URL: \(url.absoluteString)")
        print("🔄 Current auth flow exists: \(Self.currentAuthorizationFlow != nil)")
        if let currentFlow = Self.currentAuthorizationFlow {
            let resumed = currentFlow.resumeExternalUserAgentFlow(with: url)
            print("🔄 Flow resumed: \(resumed)")
            if resumed {
                Self.currentAuthorizationFlow = nil
            }
        } else {
            print("⚠️ No current authorization flow to resume!")
        }
    }

    func authorize(_ completion: @escaping (Result<OIDAuthState, Error>) -> Void) {
        print("🚀 Starting Outlook authorization...")
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
        )

        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: Self.clientID,
            clientSecret: nil,  // Public clients don't use secrets
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

        print("🚀 Opening browser for authorization...")
        Self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { state, error in
            print("🔄 Authorization callback received!")
            if let state = state {
                print("✅ Auth state received: \(state)")
                completion(.success(state))
            } else {
                print("❌ Auth error: \(String(describing: error))")
                completion(.failure(error ?? NSError(domain: "OutlookAuth", code: -1, userInfo: nil)))
            }
        }
        print("🚀 Authorization flow started: \(Self.currentAuthorizationFlow != nil)")
    }
}

