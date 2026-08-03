# Spec: paid multi-account (Mail Notifier Pro, pay what you want, Polar)

Status: built, unverified in Xcode. Target release 3.6.0 (build 28). Polar and
Doppler setup is the remaining manual work; see `tasks/polar-setup.md`.

## Goal

One email account stays free forever. A second and any further account require
**Mail Notifier Pro**, a yearly pay-what-you-want subscription with a $0.99
minimum and $5.99 suggested, sold through Polar (polar.sh) as merchant of record.
The gate is a Polar license key that the app validates directly against Polar's
customer-portal endpoints, which need no auth and no server of ours.

This ports the model already running in `../sync-bar`, minus the parts Mail
Notifier does not need: no metered usage relay, no consent checkbox (Mail
Notifier collects no personal data for billing), one paid capability instead of a
`PaidFeature` registry.

## Decisions already made

- **Name and price:** the plan is **Mail Notifier Pro**, a yearly subscription
  priced **pay what you want**: $0.99 minimum, $5.99 pre-filled at checkout. One
  product, one price entry. No trial, no lifetime tier yet. The app never learns
  the amount, so PWYW costs zero code; the entitlement is the license key alone.
- **No grandfathering.** There is no installed base to protect, so the gate
  applies to everyone from 3.6.0 onward.
- **Inside the shared Strategic Nerds Polar organization**, alongside Sync Bar,
  which is the right shape for a parent company: one payout account, one tax
  setup, one dashboard. The cost is that the benefit pin below stops being
  optional. Polar's license endpoint grants on organization membership, so
  without the pin a Sync Bar subscriber's key unlocks Mail Notifier.
- **No activation limit.** A subscription covers every Mac the person owns.
  Activation still happens, because it is what names a device in the customer
  portal and hands back the activation id used on validate and deactivate.
- **Config comes from Doppler**, project `mail-notifier`, through a new
  `scripts/pull-secrets.sh` ported from sync-bar.
- **Lapse behavior:** extra accounts go inactive, config preserved. Nothing is
  deleted, tokens stay in the Keychain, paying restores everything at once.
- **Free slot:** the first *enabled* account in stored order runs free. The
  sidebar has no drag reordering, so a locked account's banner carries a "Use
  this one instead" button that moves it to the front. Without that, whichever
  account was added first keeps the free slot forever, which is the wrong one
  often enough to matter.

## What the user sees

1. **Adding the second account.** The two provider cards in `WelcomeView` open a
   paywall sheet instead of starting OAuth when the install already has an
   account and is not entitled. The sheet shows the price, a **Get Mail Notifier
   Pro (pay what you want)** button that opens the Polar checkout in the browser,
   a collapsed "Already have a license key?" paste field, and a "Why charge?"
   disclosure.
2. **After paying.** The user pastes the key from Polar's confirmation email into
   the paste field. Activation stores the key plus the per-device activation id
   in the Keychain, and every account unlocks immediately.
3. **Lapsing.** Accounts past the first stop fetching, show a "Locked" badge in
   the sidebar, and their detail view carries a banner with a Subscribe button.
   Unread counts, notifications, and menu rows for those accounts go quiet
   because they no longer have a fetcher.
4. **Settings.** A Subscription card shows the current state (Free, Active with a
   renewal date, or Lapsed), a Subscribe or Manage subscription link to the Polar
   customer portal, the license paste field, and Remove license.

## Architecture

Three new services, lifted from sync-bar with the multi-feature indirection
removed.

### `LicenseProvider.swift`

Provider-neutral protocol plus the normalized types: `LicenseStatus`
(`state`, `expiresAt`, `customerId`, `benefitId`), `LicenseActivation`, and
`LicenseError`. Swapping billing providers means writing one conformer.

`LicenseStatus.State` is `granted | revoked | disabled | unknown`, matching
Polar's license key statuses.

### `PolarLicenseClient.swift`

Conforms `LicenseProvider` against three endpoints, all unauthenticated:

    POST {base}/v1/customer-portal/license-keys/activate
         { key, organization_id, label }        -> { id, license_key: {...} }
    POST {base}/v1/customer-portal/license-keys/validate
         { key, organization_id, activation_id } -> license key object
    POST {base}/v1/customer-portal/license-keys/deactivate
         { key, organization_id, activation_id }

Base URL defaults to `https://api.polar.sh` and is overridable to
`https://sandbox-api.polar.sh` for testing.

All parsing lives in static functions so it unit-tests with fixture JSON and no
network, the same shape as sync-bar's client.

**Benefit pinning, and why it is required.** Polar's validate endpoint takes a key
and an organization id, and grants on organization membership: every active key in
the Strategic Nerds organization validates against every product in it. Sync Bar's
subscribers hold such keys. The only thing separating the two apps is the
`benefit_id` on the validated key, which the client compares against
`PolarBenefitID`.

So `POLAR_BENEFIT_ID` is required in any shipped build.
`PolarConfig.isBenefitPinMissing` catches a build that sells subscriptions with no
pin, and `AppDelegate` logs it at launch, because the symptom otherwise is silent
revenue leaking to people who paid for a different app.

Two fail-open paths, both logged. No pin configured, which is a fork or dev build
with no paywall anyway. And a response with no `benefit_id`: if Polar ever stops
sending the field, failing closed would lock out every paying customer on the same
day, while failing open costs at most a sibling app's subscriber getting this one
thrown in.

Polar's docs are ambiguous about whether `benefit_id` is also accepted as a
*request* field. Checking the response works either way.

### `EntitlementManager.swift`

`@MainActor ObservableObject`, one shared instance. Owns:

- the license key and activation id, in the Keychain (`KeychainAccess`, same
  `com.strategicnerds.MailNotifierApp` service the OAuth tokens use, under
  `license.key` and `license.activation_id`),
- one cached `EntitlementRecord` in UserDefaults (`entitlement.record.v1`):
  `statusRaw`, `expiresAt`, `customerId`, `lastValidatedAt`,
- `isEntitled`, the derived gate every check reads,
- `activate(key:)`, `validateNow()`, `removeLicense()`,
- a launch validate plus a daily re-check at 00:00 America/Los_Angeles.

**Grace.** A successful validate replaces the record. A network failure or
transient server error leaves the prior record alone, so an outage never locks
out someone who paid. An explicit bad key lapses immediately. Both the fold
(`reduce`) and the gate (`isEntitled`) are pure static functions, unit-tested
without the network or the clock.

### Where the gates go

- **Add gate, UI:** `WelcomeView` presents the paywall sheet instead of calling
  `Accounts.authorize(type:)` when `Accounts.default.count >= 1 && !isEntitled`.
- **Add gate, model:** the success branch of `Accounts.authorize` refuses to
  `add(account:)` a *new* account under the same condition and posts
  `.showPaywall` instead. Updating an existing account (reauthorize) is never
  gated. This second check is what makes the gate real: every add path in the
  app, present and future, funnels through this one function.
- **Run gate:** `FetcherManager.rebuild()` builds fetchers from
  `Accounts.active(isEntitled:)` rather than `.enabled`. One line, and it takes
  unread counts, notifications, menu rows, and background fetching with it.
- **Display gate:** `Sidebar`, `AccountView`, `MenuBarPopover`, and
  `ClassicMenuBuilder` read the locked set to badge rows and route a click to the
  paywall.

The partition itself is pure and lives on `Accounts`:

```swift
static let freeAccountLimit = 1

/// Enabled accounts split into the ones that may run and the ones the
/// subscription gates. When entitled, everything runs.
static func partition(enabled: [Account], isEntitled: Bool) -> (active: [Account], locked: [Account])
```

## Configuration

Four new Info.plist keys, fed from `Secrets.xcconfig` through `project.yml` build
settings, read the way `GoogleClientID` already is. None are secret.

| Key | Build setting | Purpose |
| --- | --- | --- |
| `PolarOrgID` | `POLAR_ORG_ID` | Organization UUID, required to validate |
| `PolarBenefitID` | `POLAR_BENEFIT_ID` | License Keys benefit UUID. Required: it is what separates this app from Sync Bar |
| `PolarCheckoutURL` | `POLAR_CHECKOUT_URL` | Hosted checkout the Subscribe button opens |
| `PolarPortalURL` | `POLAR_PORTAL_URL` | Customer portal, linked from Settings |
| `PolarAPIBase` | `POLAR_API_BASE` | Empty for live, sandbox base for testing |

A missing `POLAR_ORG_ID` disables Subscribe and leaves the app permanently on the
free tier, so forks and dev builds without the config still work.

**Gotcha:** xcconfig treats `//` as a comment, which silently truncates
`https://…` to `https:`. sync-bar solves this with a `SLASH = /` variable and
writes URLs as `https:$(SLASH)$(SLASH)example.com`. Mail Notifier's
`Secrets.xcconfig.example` has never held a URL, so this needs adding.

## Telemetry

Standard opt-in analytics, no billing metering, so no bypass of the opt-out.
New `TelemetryEvent` cases:

- `paywall_shown` (property: `trigger` = `add_account` | `locked_account`)
- `subscribe_clicked`
- `license_activated`
- `license_activation_failed` (property: `reason`)
- `entitlement_lapsed`

Plus a user property `is_subscriber` stamped at launch, so the paid split is
measurable across the whole install base rather than only across people who
happen to fire an event.

## Files

**New**
- `Source/Services/LicenseProvider.swift`
- `Source/Services/PolarLicenseClient.swift`
- `Source/Services/EntitlementManager.swift`
- `Source/Views/PaywallSheet.swift`
- `Source/Views/Components/SubscriptionCard.swift`
- `Tests/PolarLicenseClientTests.swift`
- `Tests/EntitlementManagerTests.swift`
- `Tests/AccountEntitlementTests.swift`

**Edited**
- `Source/Models/AccountStore.swift` (partition + `freeAccountLimit`)
- `Source/Services/AccountAuthorizer.swift` (add gate in both OAuth callbacks)
- `Source/Services/FetcherManager.swift` (run gate)
- `Source/Services/TelemetryEvent.swift` (new cases)
- `Source/Utilities/Formatters.swift` (`parseISO8601`, `userMessage(for:)`)
- `Source/Utilities/NotificationNames.swift` (`.showPaywall`, `.entitlementChanged`)
- `Source/Views/WelcomeView.swift`, `Sidebar.swift`, `AccountView.swift`,
  `SettingsView.swift`, `MenuBarPopover.swift`, `ClassicMenuBuilder.swift`
- `Source/App/AppDelegate.swift` (start the manager, present the paywall)
- `Info.plist`, `project.yml`, `Secrets.xcconfig.example`
- `README.md`, `CHANGELOG.md`

## Honest limits

The gate runs entirely on the client, and Mail Notifier is on GitHub under a
permissive license. Anyone who wants to can delete the check and build their own
copy. That is true of every client-side license check and is not worth engineering
around at these prices. The gate is there so that people who want to pay have an
obvious way to, not to stop the people who don't.

## Out of scope

- Metered or usage-based billing. sync-bar's `polar-relay` exists for that and is
  not needed here.
- Family or team licensing.
- In-app checkout. Polar's hosted checkout in the browser is the whole flow.
