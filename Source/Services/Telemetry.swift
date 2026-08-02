import Foundation
import PostHog

/// Anonymous product analytics facade. All capture sites go through
/// `Telemetry.capture(...)` — no call site imports `PostHog` directly.
/// That keeps the backends swappable: add or remove a provider by editing the
/// `backends` array in `setup()` and nothing else in the app changes.
///
/// Identity: per-install UUID stored in UserDefaults. Same user across
/// reinstalls or multiple Macs appears as multiple distinctIds. No PII,
/// no email, no device fingerprint. The same UUID is used as PostHog's
/// distinctId and GA4's client_id so the two agree on who a person is.
///
/// Opt-in: defaults ON, respected from UserDefaults. User can flip the
/// switch in Settings → General. On opt-out we call `optOut` so any
/// buffered events are dropped and capture stops immediately.
///
/// Config, all from Info.plist. A missing `POSTHOG_API_KEY` silently disables
/// PostHog, so dev builds without the key baked in don't spam the prod project.
///
///   POSTHOG_API_KEY     project token, injected from Doppler at build time
///   POSTHOG_HOST        defaults to https://us.i.posthog.com
///   TELEMETRY_SOURCE    attached to every event as `source`
enum Telemetry {

    // MARK: - Storage keys

    private static let bundleId = Bundle.main.bundleIdentifier ?? "com.strategicnerds.unknown"
    private static var distinctIdKey: String { "\(bundleId).telemetry.distinctId" }
    static var optInKey: String { "\(bundleId).telemetry.optIn" }

    // MARK: - Backend wiring

    /// The live backends. `nonisolated(unsafe)` is deliberate: telemetry is
    /// callable from any actor context (notifications delegate, background
    /// tasks, UI), and the concrete backends are thread-safe internally. The
    /// only write happens once at `setup()`; reads after that are safe without
    /// a lock.
    nonisolated(unsafe) private static var backends: [TelemetryBackend] = []

    // MARK: - Public API

    /// Reads the user's current opt-in preference. Defaults to `true` when
    /// unset so first-run captures start flowing immediately; the toggle in
    /// Settings lets the user turn it off at any time.
    static var isOptedIn: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: optInKey) == nil { return true }
        return defaults.bool(forKey: optInKey)
    }

    /// Updates the opt-in preference and propagates to every live backend.
    static func setOptedIn(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: optInKey)
        for backend in backends {
            value ? backend.optIn() : backend.optOut()
        }
    }

    /// Boots the configured backends. Called once from AppDelegate.
    ///
    /// Each provider is independent: PostHog missing its key does not stop GA4,
    /// and vice versa. Add a provider by appending to `backends` here.
    static func setup() {
        var configured: [TelemetryBackend] = []
        let id = distinctId()

        if let apiKey = plistString("POSTHOG_API_KEY"),
           // Reject the unsubstituted XcodeGen/Xcode build setting placeholder
           // ("$(POSTHOG_API_KEY)") that survives when the env var is unset.
           !apiKey.hasPrefix("$(") {
            let host = plistString("POSTHOG_HOST") ?? "https://us.i.posthog.com"
            configured.append(PostHogBackend(apiKey: apiKey, host: host, distinctId: id))
        }


        for backend in configured {
            backend.setup()
            isOptedIn ? backend.optIn() : backend.optOut()
        }

        backends = configured
    }

    /// Captures a business-meaningful event. `properties` must never carry
    /// PII — no emails, no workspace names, no URLs, no user-entered text.
    /// `source` and `app_version` are attached automatically.
    /// `userProperties` are set on the person, not the event. Use them for
    /// current-state facts you want to segment people by — "which menu style
    /// is this install on" — because an event breakdown counts events, and a
    /// person who never touches a setting fires no event at all.
    static func capture(_ event: TelemetryEvent,
                        properties: [String: Any] = [:],
                        userProperties: [String: Any]? = nil) {
        capture(event.rawValue, properties: properties, userProperties: userProperties)
    }

    /// String overload, for the rare call site that builds a name dynamically.
    /// Prefer the `TelemetryEvent` version so names cannot drift.
    static func capture(_ event: String,
                        properties: [String: Any] = [:],
                        userProperties: [String: Any]? = nil) {
        guard isOptedIn else { return }

        var props = properties
        if let source = plistString("TELEMETRY_SOURCE") {
            props["source"] = source
        }
        if let version = plistString("CFBundleShortVersionString") {
            props["app_version"] = version
        }

        for backend in backends {
            backend.capture(event: event, properties: props, userProperties: userProperties)
        }
    }

    // MARK: - Private helpers

    private static func plistString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else { return nil }
        return value
    }

    private static func distinctId() -> String {
        if let existing = UserDefaults.standard.string(forKey: distinctIdKey) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: distinctIdKey)
        return fresh
    }
}

// MARK: - Backend contract

/// Abstract contract for a telemetry backend. To add a provider, conform a new
/// type and append it to `configured` in `Telemetry.setup`.
protocol TelemetryBackend {
    func setup()
    func capture(event: String, properties: [String: Any], userProperties: [String: Any]?)
    func optIn()
    func optOut()
}

// MARK: - PostHog adapter

final class PostHogBackend: TelemetryBackend {
    private let apiKey: String
    private let host: String
    private let distinctId: String

    init(apiKey: String, host: String, distinctId: String) {
        self.apiKey = apiKey
        self.host = host
        self.distinctId = distinctId
    }

    func setup() {
        let config = PostHogConfig(apiKey: apiKey, host: host)
        // Disable PostHog's built-in auto-captures — we only want the
        // explicit business events we fire ourselves. Lifecycle and screen
        // events from a SwiftUI menu-bar app aren't meaningful and would
        // dominate the event stream.
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.identify(distinctId)
    }

    func capture(event: String, properties: [String: Any], userProperties: [String: Any]?) {
        PostHogSDK.shared.capture(event, properties: properties, userProperties: userProperties)
    }

    func optIn() {
        PostHogSDK.shared.optIn()
    }

    func optOut() {
        PostHogSDK.shared.optOut()
    }
}
