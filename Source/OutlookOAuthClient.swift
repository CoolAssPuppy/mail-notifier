import Foundation
import AppAuth

struct OutlookOAuthClient {
    private init() {}
    static let shared = OutlookOAuthClient()

    // Replace with your own Azure app credentials
    static let clientID = "YOUR_OUTLOOK_CLIENT_ID"
    static let clientSecret = OutlookOAuthSecret.secret
    static let redirectURL = "msalYOUR_OUTLOOK_CLIENT_ID://auth"

    static var currentAuthorizationFlow: OIDExternalUserAgentSession?

    func authorize(_ completion: @escaping (Result<OIDAuthState, Error>) -> Void) {
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
        )

        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: Self.clientID,
            clientSecret: Self.clientSecret,
            scopes: ["https://graph.microsoft.com/Mail.Read"],
            redirectURL: URL(string: Self.redirectURL)!,
            responseType: OIDResponseTypeCode,
            additionalParameters: ["prompt": "select_account"]
        )

        Self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { state, error in
            if let state = state {
                completion(.success(state))
            } else {
                completion(.failure(error ?? NSError(domain: "OutlookAuth", code: -1, userInfo: nil)))
            }
        }
    }
}

