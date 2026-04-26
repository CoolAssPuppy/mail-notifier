# Tech debt audit — Mail Notifier

Generated: 2026-04-26
Repo: `mac-apps/mail-notifier` (Swift / macOS menu-bar app, ~5,800 LOC across 39 Swift files, no tests)
Method: Phase-1 orient (manifest, README, churn, sizes), Phase-2 nine-dimension audit, file:line citations throughout. The earlier `AUDIT_REPORT.md` (commit `592c114`) was reviewed; findings already addressed by `b0db9d9` ("security and reliability hardening") are noted as RESOLVED below where relevant. New findings carry no marker.

This audit is opinionated. Not all findings are equal — the Top 5 section is where the actual leverage is.

## Executive summary

1. **The app ships with PostHog telemetry but the welcome screen tells users "No telemetry, no analytics, no servers."** That string is in `Source/Views/WelcomeView.swift:107` and PostHog is wired in `Source/Services/Telemetry.swift`. This is a trust regression introduced in commit `5a0d812`. Either remove the telemetry, gate it on opt-in with a clear first-run prompt, or change the copy.
2. **Account state mutations (`Accounts.default.update(...)`) are not atomic and are reachable from background threads** (e.g. `OutlookProvider.didChange` via AppAuth's token-refresh callback). Read-modify-write through a UserDefaults-backed static computed property can drop concurrent writes — including freshly refreshed token state.
3. **`GmailProvider` collapses every error to `.authenticationRequired`** (`Source/Services/Providers/GmailProvider.swift:60-62, 90-92, 125-127`). A network blip flips an account into "Authorization expired" UI and clears its messages. The audit-report fix landed in `OutlookProvider`; `GmailProvider` was missed.
4. **`Localizable.strings` files in all 22 locales are stale** — they are still the 2009 Gmail Notifr files (`Resources/en.lproj/Localizable.strings:1-7` literally credits "James Chen 8/4/09"). The new code only uses 6 `NSLocalizedString` keys; everything else in those `.lproj` folders is dead, and several languages will silently fall back to English. README's "Localized in 22 languages" claim does not match reality.
5. **`Source/OAuthSecret.swift` and `Source/OAuthSecret.swift.gyb` are dead code** — nothing references `OAuthSecret`, the live OAuth secrets come from `Info.plist` via `Bundle.main.object(forInfoDictionaryKey:)` in `GoogleOAuthClient`/`OutlookOAuthClient`. The `vendors/gyb` toolchain and the `preBuildScripts` block in `project.yml:82-96` exist solely to maintain this dead path.
6. **`Secrets.xcconfig.example:12` advertises `OUTLOOK_CLIENT_SECRET`** but `OutlookOAuthClient.swift:57` passes `clientSecret: nil` and never reads it. New contributors will set a value that does nothing.
7. **`AppDelegate.swift` is the architecture's god object** — 565 lines, 12 NotificationCenter subscriptions, owns popover/menu/window/URL/mailto/notification-delegate lifecycles. NotificationCenter is the de-facto state bus: 12 `post` sites + 17 subscribe sites across Models, Services, Views, and App.
8. **Notification handler casts (`notification.object as? Account`) silently drop on type mismatch** — there is no runtime contract enforcing what each `Notification.Name` carries. `messagesFetched` posts a `String`, `accountAdded` posts an `Account`, `mailToReceived` posts a `URL`. A typo in either side fails silently.
9. **No tests exist anywhere.** `project.yml:50` sets `testTargets: []` explicitly. For an app that handles OAuth flows, persists tokens to keychain, and routes deep links, this is the single biggest sustainability risk.
10. **Build hygiene is poor**: `dist/` (~470 MB of `.dmg` + `.xcarchive` from every release) is committed and not gitignored, `vendors/gyb.py` is committed with a UTF-8 BOM in `Localizable.strings` files (binary noise in diffs), and `Info.plist:32` hardcodes the developer's specific Google client ID alongside the runtime-substituted `$(GOOGLE_CLIENT_ID)`.

## Architectural mental model

Mail Notifier is a SwiftUI-on-AppKit menu-bar app. There are three persistence stores and one notification bus tying everything together:

- `UserDefaults` holds the `accounts` JSON blob (`Accounts` is `RawRepresentable` over JSON), the `vipList`, the active theme, the unread-count toggle, the telemetry opt-in, and the per-install distinct ID.
- The login keychain (`com.strategicnerds.MailNotifierApp`) holds, per account, an archived `GTMAppAuthFetcherAuthorization` (Gmail) or `OIDAuthState` (Outlook).
- `NSUbiquitousKeyValueStore` holds the email-to-friendly-name map, mirrored back to UserDefaults.

The flow:

1. `AppDelegate` boots `Telemetry`, `FriendlyNameStore`, the status item, the popover model, and `FetcherManager.shared`.
2. `FetcherManager` keeps one `MessageFetcher` per enabled account. Each fetcher owns a `Timer` and a `MailProvider` (Gmail or Outlook). The provider uses callback APIs (`completion: @escaping (Result<...>)`) to fetch unread count and recent messages in parallel via `DispatchGroup`.
3. Results flow back into `MessageFetcher` which mutates two stored properties (`unreadMessagesCount`, `messages`); each `didSet` posts a NotificationCenter event.
4. The popover SwiftUI view (`MenuBarPopover`) and main window (`MainView` → `Sidebar` + `AccountView`) subscribe to the same NotificationCenter events and refresh their view models.
5. OAuth callbacks come back through a custom URL scheme handled by `setupURLHandler`/`URLRouter` and re-enter the AppAuth library via `resumeAuthFlow`.

The README's `Project structure` section is materially out of date. It documents files that don't exist as listed and omits files that do — see Doc-1 in the findings table.

## Findings

| ID | Category | File:Line | Severity | Effort | Description | Recommendation |
|----|----------|-----------|----------|--------|-------------|----------------|
| Sec-1 | Trust / honesty | `Source/Views/WelcomeView.swift:107` | Critical | S | First-run trust copy says "No telemetry, no analytics, no servers" while `Telemetry.swift` ships PostHog enabled-by-default and reads `POSTHOG_API_KEY` from `Info.plist:82-83`. | Either change the copy to match reality (e.g. "Anonymous usage stats only — toggle in Settings") and surface the opt-out on first run, or remove `Telemetry.setup()` from `AppDelegate.swift:36`. Pick one. Don't ship both. |
| Sec-2 | Telemetry / opt-in | `Source/Services/Telemetry.swift:42-46` | High | S | `isOptedIn` defaults to `true` for first-run users so events flow before the user sees the toggle. Combined with Sec-1, this is opt-out telemetry being marketed as "no telemetry". | Default to `false` and prompt on first launch, or move the toggle to Welcome. |
| Sec-3 | Race / persistence | `Source/Services/Providers/GmailProvider.swift:36-42`, `Source/Services/Providers/OutlookProvider.swift:62-67` | High | M | `didChange` is invoked by AppAuth on the token-refresh thread, then calls `Accounts.default.update(account:)` which is read-modify-write on a static computed property. Concurrent fetches and writes can drop refreshed token state. | Funnel `didChange` work onto `@MainActor` (or a single serial actor for `Accounts`), or refactor `Accounts.default` into an actor-backed repository. |
| Sec-4 | Race / atomicity | `Source/Models/AccountStore.swift:65-68, 96-129` | High | M | Every `add`/`delete`/`update`/`reorder` reads `Accounts.default` (full deserialization), mutates the local copy, calls `save()` which writes back. There's no lock and no actor isolation — two writers racing each other clobber state. | Same fix as Sec-3: collapse mutation through a single `AccountRepository` actor. |
| Sec-5 | URL handling | `Source/App/AppDelegate.swift:108-122` | Medium | S | `handleGetURLEvent` rejects URLs over 8,192 chars but otherwise hands the string to `URL(string:)` and routes any matching scheme. The 8,192 cap is by `String.count` (grapheme clusters), not UTF-16/byte length — the actual Apple Event payload limit is independent. | Switch the cap to `urlString.utf8.count` and document why 8,192 is the chosen value. |
| Sec-6 | Sandbox posture | `project.yml:41`, `MailNotifier.entitlements:1-15` | Medium | L | App is unsandboxed (`ENABLE_APP_SANDBOX: NO`) and the entitlements file is empty. Hardened runtime is on, but sandbox would meaningfully constrain blast radius if a token is exfiltrated via a future bug. | Evaluate sandboxing the app — keychain access and network are sandbox-compatible. The blocker is likely `LSCopyApplicationURLsForURL` in `Browser.swift:39` (used to enumerate browsers). Document the trade-off in an ADR if you decide to stay unsandboxed. |
| Sec-7 | Shipped credential | `Info.plist:32`, `Info.plist:40` | Medium | S | `CFBundleURLSchemes` hardcodes a specific Google client ID (`191228481940-…`) and a specific Microsoft `msal…` ID even though the corresponding `clientID` values come from `Secrets.xcconfig` at build time. A new contributor following the README will get the schemes wrong. | Generate the URL-scheme entries from xcconfig at build time (gyb already exists in `vendors/`) or document loudly that `Info.plist` must be hand-edited per developer. |
| Sec-8 | Bundled key | `Info.plist:82-83` | Low | S | `POSTHOG_API_KEY` is bundled into every shipped DMG. PostHog write keys are public-by-design, but anyone who downloads the DMG can fire arbitrary events into the project. | Document that this is acceptable per PostHog's threat model, or front telemetry with a server-side proxy if abuse becomes a problem. |
| Reliab-1 | Error flattening | `Source/Services/Providers/GmailProvider.swift:60-62, 90-92, 125-127` | Critical | S | Every non-success branch returns `.authenticationRequired`. A transient network failure flips the account to "Auth expired" in the UI, hides recent messages, and prompts the user to reauthorize. The `OutlookProvider` got the proper error mapping (HTTP 401 vs network vs parse) but `GmailProvider` was missed. | Inspect `error` for `NSURLErrorDomain` codes vs Google's auth-expired signal; map to `.networkError`, `.httpError`, `.authenticationRequired` accordingly. The audit-report fix from `b0db9d9` left this file alone. |
| Reliab-2 | Stale `MessageFetcher.account` | `Source/Services/MessageFetcher.swift:11, 26-41`, `Source/Services/FetcherManager.swift:46-47` | High | S | `FetcherManager.rebuild()` does `existingFetcher.account = account` to update an in-flight fetcher, but there's no synchronization with an in-flight `performFetch` whose `messages.didSet` will then write the *old* `account.newestMessageDate` back to `Accounts.default`. | Make `MessageFetcher.account` private and update only inside `fetch()` after `performFetch` completes, or capture the email-only and re-derive from `Accounts.default` in `didSet`. |
| Reliab-3 | Notification fan-out cost | `Source/Services/MessageFetcher.swift:19-23, 26-41` | Medium | S | Both `didSet` blocks fire NotificationCenter events on every assignment, even when value hasn't changed. `MenuBarPopoverModel` debounces 50ms; `AppDelegate.updateMenuBar` does not. | Guard with `oldValue != newValue` in both `didSet` bodies. |
| Reliab-4 | Unsynchronized timer in `Timer.scheduledTimer` | `Source/Services/MessageFetcher.swift:54-63` | Low | S | `reschedule()` invalidates and reschedules a `Timer` from whichever thread called `fetch()`. `Timer.scheduledTimer` requires a runloop on the calling thread; `applyFetchResults` is `.main` so this works in practice, but it's not enforced. | Mark `MessageFetcher` `@MainActor` and remove the unused `@objc func fetch()` ceremony; SwiftUI Timers can come from `Combine.Timer.publish`. |
| Reliab-5 | `messages` empty-array branch silently drops `lastCheckedAt` | `Source/Services/MessageFetcher.swift:27-41, 130-136` | Low | S | When `messagesResult` is `.failure`, `lastCheckedAt` is never updated even on a successful unread-count call. The "Last checked at hh:mm" footer freezes during partial outages. | Update `lastCheckedAt` whenever any fetch resolves, success or failure. |
| Arch-1 | God object | `Source/App/AppDelegate.swift:21-565` | High | L | 565 lines of mixed concerns: status item, popover, right-click menu, window, URL routing, Apple Events, mailto, NotificationServiceDelegate, NSWindowDelegate, NSPopoverDelegate, telemetry. 12 NC subscriptions in one place. | Extract `StatusItemController`, `PopoverController`, `WindowController`, and `URLEntryPoint` into separate `@MainActor` types. AppDelegate becomes a wiring shell. |
| Arch-2 | NotificationCenter as state bus | 12 post sites / 17 subscribe sites across Models, Services, Views | High | L | `Notification.Name` carries opaque `Any` payloads that the receiver re-casts. Compile-time contract is none. The receiver in `AppDelegate.swift:188-194` reads `notification.object as? String ?? ""` — silent failure on type mismatch. | Introduce typed event channels (Combine subjects, `AsyncStream`s, or a small `EventBus<T>` per topic). Same observer model, type-safe payloads. |
| Arch-3 | Three account stores cooperate by convention | `Source/Models/AccountStore.swift`, `Source/Services/AccountAuthorizer.swift`, `Source/Models/FriendlyNameStore.swift` | Medium | M | Account identity is JSON in UserDefaults (`Accounts.default`), authorization is `OIDAuthState`/`GTMAppAuthFetcherAuthorization` in keychain, friendly name is in `NSUbiquitousKeyValueStore`. Three places to keep in sync, no transactional guarantee. | Acceptable for the size of this app, but add a single `AccountRepository` facade so callers don't reach into all three independently. |
| Arch-4 | `Accounts.default` static get/set | `Source/Models/AccountStore.swift:65-68` | Medium | S | `Accounts.default` is a static computed property whose getter does a full JSON decode every call. The popover model alone calls it 1× per refresh (debounced 50ms). | Cache the deserialized struct behind the actor in Sec-4's fix; invalidate on `set`. |
| Arch-5 | `Sound.isCustomSound` lists all custom cases by hand | `Source/Models/Sound.swift:30-62` | Low | S | Every new custom sound requires editing both the case list and the `isCustomSound` switch (in addition to dropping the AIFF). Three-place edit for a one-fact change. | Replace with `Bundle.main.url(forResource: rawValue, withExtension: "aiff", subdirectory: "Sounds") != nil` once at startup, or a `Set<Sound>` literal. |
| Arch-6 | Two singletons + one ObservableObject hybrid for theming | `Source/Models/ThemeStore.swift:406-447` | Low | M | `ThemeStore.shared` is a singleton ObservableObject and the active palette is *also* injected via `Environment(\.theme)`. Two ways to read the same state. | Pick one. The Environment value is the SwiftUI-idiomatic answer. |
| Cons-1 | Two HTTP clients, two error styles | `Source/Services/Providers/GmailProvider.swift` (GoogleAPIClient batch) vs `Source/Services/Providers/OutlookProvider.swift:121-193` (`URLSession.shared`) | Low | — | Justified — different SDKs. | No action; noted for awareness. |
| Cons-2 | `AccountStore`, `VIPList`, friendly names — three nearly-identical persistence shapes | `Source/Models/AccountStore.swift:12-60`, `Source/Models/VIP.swift:22-71` | Medium | M | `Accounts` and `VIPList` are both hand-rolled `RawRepresentable + RandomAccessCollection + MutableCollection` over `[T]` with identical add/delete/update/save plumbing. ~50 lines duplicated per type. | Extract a generic `JSONUserDefaultsCollection<Element: Codable & Identifiable>` that both wrap. |
| Cons-3 | URL-scheme construction is split | `Source/Services/OAuth/GoogleOAuthClient.swift:30-36`, `Source/Services/OAuth/OutlookOAuthClient.swift:20-26`, `Info.plist:32, 40` | Medium | S | `redirectScheme` is computed at runtime from `clientID`. `Info.plist` hardcodes the matching scheme. If they diverge, OAuth silently fails after the redirect. | Synthesize `Info.plist`'s URL-scheme entries from xcconfig (gyb is already present), or assert at startup that `Bundle.main.urlSchemes.contains(redirectScheme)`. |
| Cons-4 | `URL(string:)!` force-unwrap idiom is inconsistent | `Source/Models/Account.swift:57, 59`, `Source/Models/Message.swift:60, 67`, `Source/Views/SettingsView.swift:306`, `Source/App/AppDelegate.swift:399` | Low | S | All-constant URLs are unwrapped, but the SettingsView one (`URL(string: url)!`) takes a parameter that is always a constant from a sibling function. Reads as if it could fail. | Add a `URL.staticURL("https://…")` helper or just use `if let`. |
| Type-1 | `Notification.object` is `Any?` everywhere | `Source/App/AppDelegate.swift:131, 148, 190, 199`, `Source/Models/AccountStore.swift:100, 109, 118, 128`, `Source/Services/MessageFetcher.swift:21, 39` | High | M | See Arch-2. The type system is bypassed on every cross-module event. | Same fix as Arch-2. |
| Type-2 | `notification.object as? String ?? ""` masks errors | `Source/App/AppDelegate.swift:190` | Low | S | Empty-string fallthrough lets the rest of the handler run with `email = ""`, then `notificationService.handleMessagesFetched(email: "", …)` does a `find(email: "")` returning nil. Silent dead path. | `guard let email = notification.object as? String else { return }`. |
| Test-1 | No test target | `project.yml:50` (`testTargets: []`) | Critical | L | OAuth callback parsing, URL routing, JWT-free identity flow, Outlook HTTP error mapping, account-state reducers — all untestable without a test target. | Add an `MailNotifierTests` target with at least: `URLRouter` cases (preferences/google/outlook/mailto/junk), `Account` JSON round-trip, `Sound.nsSound` for every case, and `MessageFetcher.applyFetchResults` truth table over `(unreadResult, messagesResult)` permutations. |
| Test-2 | `MessageFetcher.applyFetchResults` has 9 result combinations and zero coverage | `Source/Services/MessageFetcher.swift:109-137` | High | M | Auth precedence over success, partial success, partial failure — none verified. | First test target candidate. Pure function; trivial to fixture. |
| Dep-1 | `dist/` committed | `dist/MailNotifier-3.1.0.dmg` … `dist/MailNotifier-3.2.8.xcarchive/` | High | S | 14 release versions × (DMG + sparkle.txt + xcarchive directory). `~470 MB` of binary noise. `dist/*.dmg` and `dist/*.sparkle.txt` are gitignored at `.gitignore:30-31` *now* but the existing files were committed before the ignore lines landed. | `git rm -r --cached dist/MailNotifier-*.{dmg,sparkle.txt,xcarchive}` and `dist/export-*/` — keep `dist/appcast.xml`. |
| Dep-2 | `OAuthSecret.swift` and `OAuthSecret.swift.gyb` are dead | `Source/OAuthSecret.swift`, `Source/OAuthSecret.swift.gyb`, `project.yml:82-96` | Medium | S | No call site references `OAuthSecret`. The `vendors/gyb` toolchain (`vendors/gyb`, `vendors/gyb.py`) and `preBuildScripts` block exist solely to regenerate this dead file. | Delete `Source/OAuthSecret.swift{,.gyb}`, remove the `preBuildScripts` block and the `excludes: ["**/*.gyb"]` line from `project.yml`, and consider removing `vendors/gyb*` entirely if no other gyb file is added soon. |
| Dep-3 | Unused config knob | `Secrets.xcconfig.example:12`, `OutlookOAuthClient.swift:57` | Low | S | Tells contributors to set `OUTLOOK_CLIENT_SECRET`; nothing reads it. Microsoft public clients don't use a secret. | Remove `OUTLOOK_CLIENT_SECRET` from `Secrets.xcconfig.example`. |
| Dep-4 | Two SDKs for the same job | `package.swift` deps in `project.yml:13-34` | Low | — | `GoogleAPIClientForREST_Gmail` (Objective-C) + `GTMAppAuth` + `AppAuth` for Google; `AppAuth` only for Outlook. Mixed bridging surface. Justified by Google's SDK requirements. | No action; flag for awareness if the Objective-C bridging produces concurrency-checking warnings under Swift 6. |
| Dep-5 | Two binary blobs in `vendors/` | `vendors/gyb`, `vendors/gyb.py` | Low | S | Apple's GYB script committed verbatim. If `OAuthSecret.gyb` is removed (Dep-2), `vendors/` can go too. | Delete after Dep-2. |
| Perf-1 | `Accounts.default.enabled` rebuilds via `Accounts(filter { … })` | `Source/Models/AccountStore.swift:76-78`, called in `FetcherManager.swift:36`, `AppDelegate.swift:246`, `Sidebar.swift:24` | Low | S | Each access does a JSON decode + `filter` + array allocation. Called on every menu refresh. | Cache after the Sec-4 actor refactor. |
| Perf-2 | Popover model recomputes from scratch on every event | `Source/Views/MenuBarPopover.swift:50-68` | Low | S | `refresh()` enumerates all accounts, builds `AccountState` snapshots, then `==`-compares to suppress publishes. Equality compare itself walks every state. | Acceptable at current scale (handful of accounts). Revisit if user counts surprise you. |
| Err-1 | `keychain` setter for `account.authorization` swallows archive errors silently to logs | `Source/Services/AccountAuthorizer.swift:31-44` | Medium | S | If `NSKeyedArchiver.archivedData` throws, the keychain entry is left whatever it was (could be stale, could be nil), the user sees no error, and the next fetch will silently degrade. | Surface a "keychain write failed — sign in again" path; or at minimum, post `.accountUpdated` with an error userInfo so the UI can warn. |
| Err-2 | Outlook profile lookup error path swallowed | `Source/Services/AccountAuthorizer.swift:141-187` | Medium | S | If Microsoft Graph returns 4xx/5xx during the post-auth profile lookup, `completion(nil)` is invoked and the user is told nothing — the OAuth dance succeeded but no account was added. | Capture the error class (network vs HTTP vs parse), display a Welcome-screen message. |
| Err-3 | Inconsistent error logging granularity | `Source/Services/AccountAuthorizer.swift:144, 165` vs `Source/Services/Providers/GmailProvider.swift:60-62` | Low | S | Some sites log with privacy annotations; some swallow without logging. | Add a single `Log.error("event", error: …, account: …)` helper used everywhere. |
| Err-4 | Top-level `try?` on UserDefaults round-trips | `Source/Models/AccountStore.swift:39, 46`, `Source/Models/VIP.swift:48, 56` | Low | S | A corrupt JSON blob silently becomes `[]`. The user loses their accounts list with no warning. | Log a `Log.app.error` on the failure branch; back up the previous raw value into a sibling key once. |
| Doc-1 | README project structure is out of date | `README.md:33-127` | High | S | README documents `Source/Services/MessageFetcher.swift` (correct) and `Source/Models/Account.swift` (correct) but is silent on `URLRouter.swift`, `AccountAuthorizer.swift`, `Telemetry.swift`, `NotificationService.swift`, `FetcherManager.swift`, `MenuBarPopover.swift`, `ThemeStore.swift`, `Theme.swift`, `MainView.swift`, `SettingsDrawer.swift`, `Formatters.swift`, `FriendlyNameStore.swift`, `AccountStore.swift`, `URLEncoding.swift`, and `Source/Services/Providers/`. README claims `MailNotifier.entitlements` is "empty" — the file actually contains commented-out iCloud KVS entitlement guidance, which is load-bearing for FriendlyNameStore behavior. | Rewrite the structure section from the actual `find Source -type f -name '*.swift'` output. |
| Doc-2 | README claims "no telemetry" implicitly via WelcomeView | `README.md:1-30`, `Source/Views/WelcomeView.swift:107` | High | S | See Sec-1. README also describes the app as built "to pass Google's CASA review" — that bar is incompatible with shipping default-on third-party telemetry without prior consent. | Pick a story; ensure README, Welcome screen, and code agree. |
| Doc-3 | CHANGELOG concatenates new app + ancestor app | `CHANGELOG.md:1-275` | Low | S | Entries from `0.1.2 (Oct 4, 2008)` describe the original Gmail Notifr — fine as historical record but confusing because the post-`b2b4c7f` rewrites are interleaved. | Add a "Mail Notifier (rewrite)" / "Gmail Notifr (legacy)" header split. |
| Doc-4 | `Localizable.strings` is the 2009 file | `Resources/en.lproj/Localizable.strings:1-7` (UTF-16 LE BOM) and 21 sibling locales | High | M | File header still credits "James Chen on 8/4/09 — Copyright 2009 ashchan.com." Most strings refer to features the rewrite removed (passwords, Compose Mail, Growl). The current Swift code uses 6 `NSLocalizedString` calls; everything else is dead text. | Regenerate `Localizable.strings` from the 6 actual call sites in `AppDelegate+Menu.swift` and `AppDelegate.swift`, then run them through your localization vendor (or remove the non-English locales until you have content for them). The README's "22 languages" claim is currently aspirational. |
| Doc-5 | `AUDIT_REPORT.md` is stale and contradictory | `AUDIT_REPORT.md:1-247` | Low | S | Earlier audit references an `Accounts.decodeJWT(_:)` function that no longer exists (commit `b0db9d9` removed it). Recommends fixes that are partly applied (URL routing, notification IDs, JWT removal) and partly not (`GmailProvider` error mapping). | Replace with this document or merge resolved findings into git history and delete. |
| Test-3 | No CI configuration | none | Medium | M | No `.github/workflows/`, no Xcode scheme set to run tests on push. Combined with Test-1, regressions ship to users via Sparkle without a single automated check. | After Test-1 lands a basic test target, add a CI job that runs `xcodebuild test -scheme MailNotifier`. |
| Hygiene-1 | `.DS_Store` committed | `.DS_Store` (binary) | Low | S | Despite `.gitignore:1` having `.DS_Store`, the file was committed before the ignore line existed. | `git rm --cached .DS_Store`. |
| Hygiene-2 | `Mail Notifier.mov` (32 MB) committed | repo root | Medium | S | `*.mov` is gitignored at `.gitignore:2` but the file is already in history. | `git rm --cached "Mail Notifier.mov"` and consider `git filter-repo` if the history bloat matters; otherwise just stop carrying it forward. |
| Hygiene-3 | Two `friendlyNames` `@ObservedObject` declarations in `Sidebar` | `Source/Views/Sidebar.swift:12, 179` | Low | S | The outer `Sidebar` declares one and never references it explicitly; the inner `SidebarAccountRow` declares another. The outer one *does* trigger SwiftUI redraws via implicit observation, which is exactly what makes this confusing. | Remove the outer one, document on the inner one why it's there. |
| Hygiene-4 | Build-version drift | `MailNotifier.xcodeproj/project.pbxproj` (modified, untracked changes) | Low | S | The pbxproj is in your `git status` as modified. xcodegen regenerates it; manual edits will be clobbered. | Either commit the regenerated pbxproj or stop opening Xcode for project edits. |

## Top 5 — if you fix nothing else, fix these

### 1. Reconcile telemetry copy with reality (Sec-1, Sec-2, Doc-2)

**Problem.** `WelcomeView.swift:107` shows "No telemetry, no analytics, no servers." Telemetry.swift sets up PostHog and `isOptedIn` defaults to `true`. The user is told one thing and another thing happens.

**Fix sketch.** Two acceptable paths — pick one:

```swift
// Option A — match the copy: remove telemetry.
// Source/App/AppDelegate.swift:36
Telemetry.setup()  // delete this line, delete Telemetry.swift, drop PostHog from project.yml.

// Option B — match the code: change the copy and prompt explicitly.
// Source/Views/WelcomeView.swift:107
trustItem(icon: "info.circle", label: "Anonymous usage stats — toggle in Settings")

// Source/Services/Telemetry.swift:42-46
static var isOptedIn: Bool {
    UserDefaults.standard.bool(forKey: optInKey)  // default false; surface a one-time prompt.
}
```

Stop shipping the contradiction. This is the lowest-effort, highest-trust-impact change in the audit.

### 2. Funnel `Accounts` mutations through one actor (Sec-3, Sec-4, Arch-3, Arch-4)

**Problem.** `Accounts.default.update(...)` is reachable from any thread, with no atomicity. The `OutlookProvider.didChange` path runs on AppAuth's background callback. Token refresh races with concurrent fetches and UI reads.

**Fix sketch.** Introduce a `MainActor`-isolated `AccountRepository` and route everything through it. NotificationCenter posts move into the repo so callers can't post the wrong shape.

```swift
@MainActor
final class AccountRepository: ObservableObject {
    static let shared = AccountRepository()
    @Published private(set) var accounts: [Account] = []

    func add(_ account: Account) { … persist + post .accountAdded … }
    func update(_ account: Account) { … }
    func delete(_ account: Account) { … }
    func setAuthorization(_ auth: GTMAppAuthFetcherAuthorization?, for email: String) async { … }
}
```

Provider `didChange` becomes:

```swift
func didChange(_ state: OIDAuthState) {
    Task { @MainActor in
        await AccountRepository.shared.setAuthorization(GTMAppAuthFetcherAuthorization(authState: state), for: accountEmail)
    }
}
```

`Accounts.default` static accessors stay only as a thin migration shim until callers are converted.

### 3. Fix `GmailProvider` error mapping (Reliab-1)

**Problem.** Every non-success completion returns `.authenticationRequired`. Users see "Authorization expired" on transient network failures.

**Fix sketch.**

```swift
// Source/Services/Providers/GmailProvider.swift
private func mapGmailError(_ error: Error?) -> MailProviderError {
    let nsError = error as NSError?
    if nsError?.domain == NSURLErrorDomain { return .networkError(error!) }
    if let status = nsError?.userInfo["GTLRStructuredErrorHTTPStatus"] as? Int {
        if status == 401 || status == 403 { return .authenticationRequired }
        return .httpError(statusCode: status)
    }
    return .parsingError(error?.localizedDescription ?? "Unknown Gmail error")
}

// then in fetchUnreadCount, fetchMessages, fetchMessageDetails:
} else {
    completion(.failure(mapGmailError(error)))
}
```

Verify with a test: airplane-mode toggle should produce `.networkError`, not the auth-expired UI.

### 4. Add a test target — start with `MessageFetcher.applyFetchResults` (Test-1, Test-2)

**Problem.** Zero tests. The most easily testable, highest-value function is `applyFetchResults` — a pure-ish reducer over `(Result<Int>, Result<[Message]>)`.

**Fix sketch.** `project.yml`:

```yaml
targets:
  MailNotifier: { … }
  MailNotifierTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests
    dependencies:
      - target: MailNotifier
```

Then `Tests/MessageFetcherTests.swift` exercises the 9 outcome combinations of (success/failure/auth) × (success/failure/auth) — auth precedence wins, partial success preserves the other path's data, etc. This is ~80 lines of test for the most leveraged pure function in the app.

Then add `URLRouterTests` — preferences URL, valid Google callback, valid Outlook callback, mailto, junk URL, missing host, wrong scheme, control characters. About 30 minutes of work, locks in the behavior already shipped in `b0db9d9`.

### 5. Delete the dead OAuth-secret toolchain (Dep-2, Dep-5)

**Problem.** `Source/OAuthSecret.swift{,.gyb}` is unreferenced. The `vendors/gyb` toolchain and the `preBuildScripts` block in `project.yml:82-96` exist solely to regenerate this dead file.

**Fix sketch.**

```bash
git rm Source/OAuthSecret.swift Source/OAuthSecret.swift.gyb
git rm -r vendors/  # unless something else depends on gyb
```

```yaml
# project.yml — remove these
sources:
  - path: Source
    excludes:
      - "**/*.gyb"   # ← delete
preBuildScripts:     # ← delete the whole block
  - name: Generate OAuth secrets
    …
```

Net: ~150 lines and one Python interpreter dependency removed. Faster builds. Less surface area.

## Quick wins

Low effort × Medium-or-higher severity. Anyone with 30 minutes can take one off the board.

- [ ] **Sec-1 / Sec-2** — Change WelcomeView copy or default `isOptedIn` to false. (5 min)
- [ ] **Reliab-3** — Add `oldValue != newValue` guards in `MessageFetcher` `didSet` blocks. (10 min)
- [ ] **Type-2** — Replace `notification.object as? String ?? ""` with a `guard let`. (5 min)
- [ ] **Dep-1** — `git rm -r --cached dist/MailNotifier-*.{dmg,sparkle.txt,xcarchive} dist/export-*/`. (15 min including verifying CI/release scripts still work)
- [ ] **Dep-2 + Dep-5** — Delete `OAuthSecret.swift{,.gyb}`, drop `preBuildScripts` and `vendors/gyb*`. (30 min)
- [ ] **Dep-3** — Remove `OUTLOOK_CLIENT_SECRET` from `Secrets.xcconfig.example`. (1 min)
- [ ] **Doc-5** — Delete `AUDIT_REPORT.md` once findings here are landed. (1 min)
- [ ] **Hygiene-1 / Hygiene-2** — `git rm --cached .DS_Store "Mail Notifier.mov"`. (5 min)
- [ ] **Doc-1** — Regenerate README "Project structure" from `find Source -type f`. (15 min)
- [ ] **Reliab-1** — Mirror `OutlookProvider`'s error mapping into `GmailProvider`. (45 min, requires Top-5 #3)
- [ ] **Cons-3** — Assert at startup that `Bundle.main.urlSchemes.contains(GoogleOAuthClient.redirectScheme)`. Catches broken xcconfig in seconds. (10 min)

## Things that look bad but are actually fine

These are calls I considered flagging and chose not to. Required section — judgment, not omission.

- **Mixed callback + async/await styles in providers.** `MailProvider` uses `Result<…>` callbacks; `NotificationService` uses `async`; `Telemetry` is fire-and-forget. Looks inconsistent on first read. But the providers are wrapping inherently callback-based SDKs (GoogleAPIClient batch queries, AppAuth `performAction`); converting to async would require `withCheckedContinuation` wrappers that don't add meaningful value. Fine.
- **`Accounts: RawRepresentable, Codable, RandomAccessCollection, MutableCollection, ExpressibleByArrayLiteral` in `AccountStore.swift:12`.** Six conformances on one struct looks heavy. But each is load-bearing: `RawRepresentable + Codable` is what makes `@AppStorage(Accounts.storageKey)` work; the collection conformances are what make `accounts.find`, `ForEach(accounts)`, and drag-to-reorder readable in views. The Cons-2 finding still stands (extract a generic), but the conformance set itself is correct.
- **`@AppStorage(Accounts.storageKey) var accounts = Accounts()` in views.** Reads as if every view owns the accounts list. But `@AppStorage` is just `UserDefaults` reactive plumbing; all views see the same store. The duplication is SwiftUI-idiomatic.
- **`MessageFetcher` as `NSObject` with `@objc func fetch()` for `Timer.scheduledTimer`.** Dated pattern but `Timer.scheduledTimer(target:selector:)` requires it. Using `Timer.scheduledTimer(withTimeInterval:repeats:block:)` would eliminate `@objc` but the result is the same. Not worth touching.
- **`nonisolated(unsafe) private static var backend: TelemetryBackend?` in `Telemetry.swift:35`.** Looks like a concurrency violation. The comment two lines up earns it: writes happen once at `setup()`, all subsequent operations are reads, and PostHog SDK is internally thread-safe. The `nonisolated(unsafe)` is the right tool for "I know what I'm doing" here.
- **`CFXMLCreateStringByUnescapingEntities` for snippet decoding (`Source/Models/Message.swift:72`).** Looks scary (Core Foundation, 1990s API). It's the right tool — Gmail snippets are HTML-entity-encoded and Foundation has no public Swift equivalent. The `_` `nil` arguments are correct (no XML doc context, no extra entities).
- **`URL(string: "https:")!` in `Source/Models/Browser.swift:39`.** Looks like a typo (missing `//`). Intentional — `LSCopyApplicationURLsForURL` wants a URL with the scheme to enumerate handlers; it doesn't need a host.
- **No `UNNotificationAction`s on notifications.** Looks like a missing feature. Mail Notifier deliberately makes notifications a "click to open" surface only; adding actions would expand the attack surface (notification payload-driven URL opens) for marginal benefit.
- **No drag-to-reorder in the new `Sidebar`.** Old changelog (2.1.0) says it existed in Gmail Notifr. The rewrite chose not to ship it. `Accounts.move(fromOffsets:toOffset:)` and `accountsReordered` notification still exist, suggesting it's a deferred-not-rejected decision. Not debt.
- **Two SwiftUI windows + an NSPopover.** Looks like architectural sprawl for a menu-bar app. But this is exactly the right shape: NSPopover for the menu-bar UI, `NSWindow` (built imperatively in `showPreferences()`) for the main window because SwiftUI's `Settings { … }` and `Window { … }` scenes don't compose with `.accessory` activation policy without dock icon flicker. The `MailNotifierApp.body { Settings { EmptyView() } }` shim is a deliberate workaround.
- **`Sound.soundName: NSSound.Name(rawValue.capitalized)` in `Source/Models/Sound.swift:75-77`.** For `iLoveYou = "i-love-you"`, `.capitalized` produces `"I-Love-You"` — not a real system sound. Looks broken. It's only called in the non-custom branch; for system cases the rawValue is single-word so capitalized is correct. The custom branch goes through `Bundle.main.url(...)` instead. Not a bug, but it's why Arch-5 is worth the cleanup — the invariant lives in two places.

## Open questions for the maintainer

Things I couldn't tell were debt vs intentional. Asking instead of asserting.

1. **Telemetry posture.** Is shipping default-on PostHog actually compatible with the README's "built to pass Google's CASA review" framing? CASA's data-handling expectations (consent, transparency) seem to require explicit opt-in. Did the CASA review consider PostHog, or did this slip in after?
2. **`MailNotifier.entitlements` empty file.** The commented-out iCloud KVS guidance in the entitlements file says "re-enable when you add the capability in Apple Developer Portal." Is the iCloud KVS capability provisioned for the production bundle ID? `FriendlyNameStore` falls back gracefully, but if it's *supposed* to work in shipped builds, it currently doesn't.
3. **`dist/` retention policy.** Is keeping every released `.dmg` + `.xcarchive` in git intentional (release-archive history) or accidental (forgot to gitignore until 3.x)? If intentional, consider git-LFS; if accidental, Dep-1 applies.
4. **Outlook for personal Hotmail accounts.** `OutlookOAuthClient.swift:42` uses the `common` tenant endpoint — this works for both personal and work accounts. But the README + Welcome card say "Hotmail, Office 365 via Microsoft." Is Office 365 actually tested? Token-refresh behavior differs (work accounts get conditional-access policies that personal accounts don't).
5. **`vendors/gyb*` removal blast radius.** Is gyb used by another project that builds against this checkout, or is `OAuthSecret.swift.gyb` the only gyb file across all your repos? Dep-5 assumes the latter.
6. **`coolasspuppy` branding inconsistency.** `Info.plist:75` and `SettingsView.swift:280, 290` use the `coolasspuppy` username; the company is "Strategic Nerds." Is this deliberate (personal-brand for the indie product, corporate-brand for the org) or unfinished migration?
7. **Sparkle update channel.** Should `SUFeedURL` (`https://coolasspuppy.com/mail-notifier-updates`) be moved to a `strategicnerds.com` host before this gets harder to migrate? Renaming the appcast URL after wide deployment is painful (can't issue an update that points elsewhere through Sparkle alone).
