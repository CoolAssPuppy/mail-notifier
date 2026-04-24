import Foundation
import PostHog

/// Anonymous product analytics facade. All capture sites go through
/// `Telemetry.capture(...)` — no call site imports `PostHog` directly.
/// That keeps the backend swappable: replace PostHog with Amplitude,
/// Mixpanel, or fan out to multiple backends by editing this file only.
///
/// Identity: per-install UUID stored in UserDefaults. Same user across
/// reinstalls or multiple Macs appears as multiple distinctIds. No PII,
/// no email, no device fingerprint.
///
/// Opt-in: defaults ON, respected from UserDefaults. User can flip the
/// switch in Settings → General. On opt-out we call `optOut` so any
/// buffered events are dropped and capture stops immediately.
///
/// Config: `POSTHOG_API_KEY`, `POSTHOG_HOST`, and `TELEMETRY_SOURCE` come
/// from Info.plist. A missing `POSTHOG_API_KEY` silently disables capture,
/// so dev builds without the key baked in don't spam the prod project.
enum Telemetry {

    // MARK: - Storage keys

    private static let bundleId = Bundle.main.bundleIdentifier ?? "com.strategicnerds.unknown"
    private static var distinctIdKey: String { "\(bundleId).telemetry.distinctId" }
    static var optInKey: String { "\(bundleId).telemetry.optIn" }

    // MARK: - Backend wiring

    /// The live backend. `nonisolated(unsafe)` is deliberate: telemetry is
    /// callable from any actor context (notifications delegate, background
    /// tasks, UI), and the concrete backend (PostHogSDK) is thread-safe
    /// internally. The only write happens once at `setup()`; reads after
    /// that are safe without a lock.
    nonisolated(unsafe) private static var backend: TelemetryBackend?

    // MARK: - Public API

    /// Reads the user's current opt-in preference. Defaults to `true` when
    /// unset so first-run captures start flowing immediately; the toggle in
    /// Settings lets the user turn it off at any time.
    static var isOptedIn: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: optInKey) == nil { return true }
        return defaults.bool(forKey: optInKey)
    }

    /// Updates the opt-in preference and propagates to the live backend.
    static func setOptedIn(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: optInKey)
        if value {
            backend?.optIn()
        } else {
            backend?.optOut()
        }
    }

    /// Boots the current backend. Called once from AppDelegate.
    static func setup() {
        guard
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String,
            !apiKey.isEmpty
        else {
            return
        }
        let host = (Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String)
            ?? "https://us.i.posthog.com"

        let instance = PostHogBackend(
            apiKey: apiKey,
            host: host,
            distinctId: distinctId()
        )
        instance.setup()
        backend = instance

        if isOptedIn {
            instance.optIn()
        } else {
            instance.optOut()
        }
    }

    /// Captures a business-meaningful event. `properties` must never carry
    /// PII — no emails, no workspace names, no URLs, no user-entered text.
    /// `source` and `app_version` are attached automatically.
    static func capture(_ event: String, properties: [String: Any] = [:]) {
        guard isOptedIn else { return }
        var props = properties
        if let source = Bundle.main.object(forInfoDictionaryKey: "TELEMETRY_SOURCE") as? String,
           !source.isEmpty {
            props["source"] = source
        }
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            props["app_version"] = version
        }
        backend?.capture(event: event, properties: props)
    }

    // MARK: - Private helpers

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

/// Abstract contract for a telemetry backend. To swap PostHog for another
/// provider, conform a new type and change the single `backend =` line in
/// `Telemetry.setup`. To fan out to multiple backends, hold `[TelemetryBackend]`
/// and iterate on capture/optIn/optOut.
private protocol TelemetryBackend {
    func setup()
    func capture(event: String, properties: [String: Any])
    func optIn()
    func optOut()
}

// MARK: - PostHog adapter

private final class PostHogBackend: TelemetryBackend {
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

    func capture(event: String, properties: [String: Any]) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    func optIn() {
        PostHogSDK.shared.optIn()
    }

    func optOut() {
        PostHogSDK.shared.optOut()
    }
}
