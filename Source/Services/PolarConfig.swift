//
//  PolarConfig.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  Polar settings, resolved at runtime the way `GoogleOAuthClient` resolves its
//  client id: values flow from the Doppler `mail-notifier` project into
//  `Secrets.xcconfig` (gitignored), which the build bakes into Info.plist. A
//  process-environment override is honored first so `doppler run -- ...` works
//  in development.
//
//  None of these are secret. The organization and benefit ids are public UUIDs,
//  and the checkout and portal links are meant to be shared. No Polar access
//  token exists in the app, because the three license-key endpoints it calls
//  need no authentication.
//
//  Every value resolves to empty or nil when unset, and `isConfigured` reports
//  the subscription as unavailable, which leaves the app permanently on the free
//  tier. That is what makes a fork or an unconfigured dev build usable.
//

import Foundation

enum PolarConfig {
    /// Polar organization UUID. Required: the license-key endpoints take it as
    /// the tenant, and there is no entitlement without it.
    static var organizationId: String { value(infoKey: "PolarOrgID", env: "POLAR_ORG_ID") }

    /// The License Keys benefit UUID. Required in any shipped build.
    ///
    /// Mail Notifier lives in the shared Strategic Nerds Polar organization
    /// alongside the other apps, and Polar's license endpoint grants on
    /// organization membership: every active key in the org validates against
    /// every product in it. This pin is the only thing separating them, so
    /// leaving it empty gives Mail Notifier away to subscribers of any sibling
    /// app.
    static var benefitId: String { value(infoKey: "PolarBenefitID", env: "POLAR_BENEFIT_ID") }

    /// True for a build that sells subscriptions but forgot the product pin.
    /// `AppDelegate` logs this at launch, because the symptom otherwise is
    /// silent revenue leaking to people who paid for a different app.
    static var isBenefitPinMissing: Bool { isConfigured && benefitId.isEmpty }

    /// Hosted checkout the Subscribe button opens. nil until the Polar product
    /// exists, which disables the button rather than opening a dead link.
    static var checkoutURL: URL? { url(infoKey: "PolarCheckoutURL", env: "POLAR_CHECKOUT_URL") }

    /// Polar customer portal, where a subscriber manages or cancels. Linked from
    /// the Settings subscription card.
    static var portalURL: URL? { url(infoKey: "PolarPortalURL", env: "POLAR_PORTAL_URL") }

    /// Polar API base. Empty in production (defaults to the live API); set to
    /// `https://sandbox-api.polar.sh` to run against Polar's sandbox, which is a
    /// wholly separate account with test cards and no real money.
    static var apiBaseURL: URL {
        url(infoKey: "PolarAPIBase", env: "POLAR_API_BASE") ?? URL(string: "https://api.polar.sh")!
    }

    /// License keys validate without a server, so an organization id alone is
    /// enough to gate the paid capability and show the paste field.
    static var isConfigured: Bool { !organizationId.isEmpty }

    // MARK: Resolution

    private static func url(infoKey: String, env: String) -> URL? {
        let raw = value(infoKey: infoKey, env: env)
        return raw.isEmpty ? nil : URL(string: raw)
    }

    private static func value(infoKey: String, env: String) -> String {
        if let fromEnv = ProcessInfo.processInfo.environment[env], !fromEnv.isEmpty {
            return fromEnv
        }
        guard let raw = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String else { return "" }
        // An unresolved build setting arrives as the literal "$(NAME)".
        if raw.isEmpty || raw.hasPrefix("$(") { return "" }
        return raw
    }
}
