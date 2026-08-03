# Todo

## Mail Notifier Pro: paid multi-account via Polar (current)

Full design in `tasks/paid-accounts-spec.md`. One account free forever, then
**Mail Notifier Pro**: a yearly pay-what-you-want subscription, $0.99 minimum and
$5.99 suggested. Polar license keys validated straight from the app, no server of
ours. Ported from `../sync-bar`. Mail Notifier Pro lives in the shared Strategic
Nerds Polar organization, which makes `POLAR_BENEFIT_ID` required rather than
optional.

### Steps
- [x] 1. `LicenseProvider.swift` + `PolarConfig.swift` + `PolarLicenseClient.swift`,
      with `Tests/PolarLicenseClientTests.swift` covering fixture parsing, HTTP
      status mapping, and the `benefit_id` mismatch rejection.
- [x] 2. `EntitlementManager.swift` (Keychain + UserDefaults + grace + daily
      00:00 Pacific check) with `Tests/EntitlementManagerTests.swift` over the
      pure `reduce`, `isEntitled`, and midnight math.
- [x] 3. Config plumbing: `POLAR_*` in `project.yml`, `Info.plist`,
      `Secrets.xcconfig.example` (with the `SLASH` variable for URLs), and
      `scripts/pull-secrets.sh` reading the Doppler `mail-notifier` project.
- [x] 4. `Accounts.partition` + `freeAccountLimit` with
      `Tests/AccountEntitlementTests.swift`.
- [x] 5. Run gate in `FetcherManager.rebuild()`.
- [x] 6. Add gate in `Accounts.canAddAccount()`, checked inside both OAuth
      success branches so every add path is covered, plus a courtesy check in
      `WelcomeView` so nobody signs in to Google only to be refused.
- [x] 7. `PaywallSheet.swift`, hosted once in `MainView`, driven by `.showPaywall`.
- [x] 8. Locked-state display: sidebar badge, `AccountView` banner, popover row
      and Subscribe pill, classic menu row.
- [x] 9. `SubscriptionCard.swift` in Settings: status, subscribe or manage,
      paste key, remove license.
- [x] 10. Telemetry events + the `is_subscriber` and `account_count` person
      properties at launch.
- [x] 11. All pricing copy pulled into `PaywallCopy.swift`, one file, so the
      pitch can be rewritten without touching SwiftUI.
- [ ] 12. Polar and Doppler setup. Step by step in `tasks/polar-setup.md`.
- [ ] 13. Build and run the tests in Xcode. Everything so far was verified with
      the bare Swift compiler; see the note below.
- [ ] 14. Sandbox end-to-end: the twelve checks in `tasks/polar-setup.md` Part 3.
      Do not skip 10 (a Sync Bar key must be rejected) or 12 (a $0.99 purchase
      must renew at $0.99, not at the $5.99 suggestion).
- [ ] 15. Release 3.6.0 (build 28). Version and CHANGELOG are already bumped.

### Verification so far
Xcode is not installed on the build Mac, only Command Line Tools, so
`xcodebuild` cannot run and neither can XCTest. Instead every file under
`Source/` was compiled as an SPM target against the real package dependencies,
and the pure logic was exercised by a standalone runner: 50 checks over the
partition, the entitlement gate, the grace rules, the midnight math, and the
Polar response parsing. All 50 pass.

That found two real bugs. `max(0, limit)` inside an `Accounts` extension bound to
`Collection.max()` rather than the global function, and `loadRecord` inherited
main-actor isolation from the class, which made the nonisolated gate read
uncompilable. Both fixed.

What that does NOT cover: the Xcode project builds the same sources with
different settings, so a clean `xcodebuild` run is still step 13. The SwiftUI
views type-check but have never been rendered.

### Open item
Confirm in the Polar sandbox whether a yearly renewal extends a license key's
`expires_at`. If it does not, a TTL on the benefit would lock out paying
customers at month 12, which is why the setup guide says to leave the expiry off
and lean on Polar's revocation-on-cancel instead.

## Classic Mode menu bar dropdown (done)

Goal: an alternative menu bar dropdown that is a standard AppKit `NSMenu` —
account rows with unread counts, a submenu of unread subjects per account, and
a thin icon strip at the bottom (check all, main window, settings on the left;
quit on the right). No themes in classic mode; it inherits the system
light/dark appearance. The main window (configuration panel) does not change.

### Steps
- [x] `MenuStyle` model + store (`settings.menuStyle`, defaults to `pretty`)
- [x] `ClassicMenuBuilder` — builds the `NSMenu` from `FetcherManager` state
- [x] `ClassicMenuFooterView` — AppKit icon strip hosted in a menu item view
- [x] `AppDelegate` routes left-click to the classic menu or the popover
- [x] Settings: "Menu Style" card in the right column, above Updates
- [x] Telemetry event for the style switch
- [x] `xcodegen generate`, build, tests

### Constraint
AppKit will not send an `NSMenuItem` action when that item owns a submenu — the
click opens the submenu instead. So an account with unread mail puts "Open
Inbox" as the first entry of its own submenu, and an account with no unread
mail (no submenu) opens the inbox on a direct click.

### Review
- Debug build succeeds. Tests: 83/84. The single failure
  (`FormattersTests.testRelativeLabelYesterday`) is the pre-existing,
  date-dependent one documented below, untouched by this work.
- Verified live: the classic menu shows three accounts with provider icons,
  "Nerds Junk (1)" opens a submenu of `Open Inbox` + the unread subject, and
  the footer strip renders the four icons with quit pinned right. System was
  in Light appearance and the menu rendered light, as intended.
- Classic mode reads messages straight from `FetcherManager` (up to the 10 the
  fetcher stores) rather than the popover model's 3-message preview, and
  appends a disabled "N more unread" row when the server count runs ahead.
- The main window is unchanged apart from the new Menu Style card.
- Testing required quitting the installed 3.4.2 app (LaunchServices refuses to
  launch the test host while another copy of the bundle id is running); it was
  relaunched afterwards and the temporary `settings.menuStyle` default removed.

## Make notification sounds respect Focus / Do Not Disturb

**Problem:** Mail Notifier plays its sound via `NSSound.play()` directly (NotificationService
`handleMessagesFetched`), separate from the `UNUserNotificationCenter` notification. Direct audio
playback is not governed by Focus, so the sound keeps playing during Focus even though the visual
banner is correctly suppressed.

**Fix:** Attach the sound to the notification (`content.sound = UNNotificationSound(...)`) and remove
the direct `NSSound.play()` calls so macOS plays the sound and honors Focus.

**Constraint (researched):** `UNNotificationSound(named:)` on macOS only searches the app container's
`Library/Sounds`, an app-group `Library/Sounds`, and the bundle's resource ROOT. It does not recurse
into bundle subfolders and does not read `/System/Library/Sounds`. So every sound file must sit at the
bundle resource root.

**Decision (user):** Bundle copies of the 14 system sounds in the app (self-contained, no global
sound-list clutter, every sound keeps its exact choice).

### Steps
- [x] Copy the 14 system sounds into `Resources/Sounds/` as `<rawValue>.aiff` (lowercase)
- [x] `project.yml`: flatten `Resources/Sounds` into the bundle root (drop the folder reference)
- [x] `Sound.swift`: load all sounds from the bundle root; add `notificationSound`
- [x] `NotificationService.swift`: remove `NSSound.play()`; attach sound to the notification (one per batch)
- [x] `SoundTests.swift`: assert every `Sound` ships a bundled `.aiff` at the resource root
- [x] `xcodegen generate`, then build + test
- [x] Verify behavior

### Review
- Debug build succeeds. Bundle inspection: all 32 `.aiff` at `Contents/Resources/` root, no `Sounds/`
  subfolder, 22 `.lproj` localizations intact.
- Tests: 83/84 pass. All 8 `SoundTests` pass, including the two new ones. The single failure
  (`FormattersTests.testRelativeLabelYesterday`) is PRE-EXISTING and unrelated: `relativeLabel` uses
  `isDateInToday`/`isDateInYesterday`, which compare against the real system date and ignore the
  `reference` arg, so the test only passes when run on 2026-04-27. Not caused by these changes.
- Remaining manual check (cannot automate here): turn on a Focus mode and send yourself an email;
  the banner and sound should both be suppressed.

### Follow-up bug: banner fired but no sound (found during testing)
Root cause: `NotificationService.setup()` requested only `[.alert]`. The old code played sound via
`NSSound` (no notification permission needed); now the sound rides on the notification, which requires
`.sound` authorization. Without it macOS shows the banner and stays silent.
- [x] Request `[.alert, .sound]` in `setup()`

UPGRADE-PATH CAVEAT: existing 3.x users are already authorized alert-only. macOS does not auto-add the
sound permission to an already-authorized app just because the code now requests it, so on update to 3.4
their notification sound stays off until they enable "Play sound for notifications" in System Settings.
New installs get the combined prompt and work out of the box.
- [x] DECIDED: no in-app nudge. Cover the manual toggle in the Sparkle release note instead
      (single-user app; release note is sufficient and keeps the change small).

### Post-release housekeeping (done)
- Backfilled CHANGELOG.md from the appcast: added 3.2.4-3.2.9, 3.3.0, 3.3.1, 3.4 (filled the whole gap, not just 3.3.x).
- Cleaned gitignored build artifacts: removed build/ (~1GB), dist/debug, dist/export-3.4, dist/*.xcarchive,
  and old release DMGs/sigs (3.1.x-3.3.x). Kept dist/appcast.xml (tracked) and the current 3.4 DMG.
- Found the *debug* build was the running + URL-handler copy; quit it, registered + launched the installed
  /Applications/Mail Notifier.app (3.4, build 22).
- Note: release.sh ran twice, so the appcast has two 3.4 items (build 22 and 23, identical code). Sparkle will
  offer a 22->23 no-op update. Optional cleanup: dedupe appcast to keep only build 23 and re-upload to R2.

### Follow-up bug: custom sound played as the default macOS sound (found during testing)
Root cause: `UNNotificationSound(named:)` on macOS does NOT resolve names from the app bundle's
Resources root (despite the files being there in a valid format). Confirmed empirically: configured
sounds (ramius/whimsy/whistle + VIP vader/i-love-you) all fell back to the default; vader is valid
16-bit lpcm at the bundle root, so it was a location problem, not a format problem.
Fix: stage the chosen sound into `~/Library/Sounds` (the documented first search path for a
non-sandboxed app) on demand, prefixed `MailNotifier-`, and reference it there.
- [x] Sound.swift: `notificationSound()` stages into ~/Library/Sounds and returns the staged sound
- [x] NotificationService: fall back to `.default` only if staging fails
- [x] Verify: real email played the custom sound; MailNotifier-ramius.aiff staged in ~/Library/Sounds
- [ ] Cut 3.4.1 with this fix (command provided; user runs release.sh)

### Behavior note
Previews (selecting a sound in Settings/Account) keep using `NSSound` for instant feedback. That is
correct: previews are not notifications and should play regardless of Focus.

Coupling tradeoff (approved): sound now plays only when the banner does. The old "sound without banner"
path is gone, which is required for Focus to govern the sound.

## Add Revolut donate link (done)
- [x] `SettingsView.swift`: add "(Revolut)" row -> https://revolut.me/coolasspuppy after "Buy me coffee"
