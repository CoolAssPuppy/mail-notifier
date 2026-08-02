import Foundation

/// Every event Mail Notifier sends, named once.
///
/// Naming: `object_action`, snake_case, action in the past tense.
/// `account_added`, `notification_shown`, `vip_removed`.
///
/// These were dot-separated (`account.added`) until 2026-07. PostHog treats the
/// dot as an ordinary character, so nothing broke, but the names sorted oddly
/// and matched nothing in the other apps. Events captured before the rename keep
/// their old names in PostHog forever; build an Action over both spellings if
/// you need a metric spanning the cut.
///
/// A typed enum rather than raw strings because a typo in a string literal is a
/// silent second event in PostHog that nobody notices for months.
enum TelemetryEvent: String {

    // MARK: Accounts
    case accountAdded = "account_added"
    case accountSigninFailed = "account_signin_failed"

    // MARK: App lifecycle
    ///
    /// Ours, not the SDK's. `captureApplicationLifecycleEvents` is off in
    /// `PostHogBackend.setup()` because a menu bar app's launch/background churn
    /// would drown the handful of events that mean something.
    case appLaunched = "app_launched"
    case updateInstalled = "update_installed"

    // MARK: Menu bar
    case menuOpened = "menu_opened"
    case menuStyleChanged = "menu_style_changed"

    // MARK: Notifications
    case notificationShown = "notification_shown"
    case notificationClicked = "notification_clicked"

    // MARK: VIPs
    case vipAdded = "vip_added"
    case vipRemoved = "vip_removed"
}
