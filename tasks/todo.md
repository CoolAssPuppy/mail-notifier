# Todo

## Release 3.8.0 (cleanup-ui)

### Plan
- [x] Finish the theme selector and verify its states in the running app.
- [x] Run the full local test and build checks on the exact source to release.
- [x] Publish a signed, notarized 3.8.0 release with the note “Some UI cleanup.”
- [x] Verify the live DMG and appcast.
- [x] Commit, fast forward main, and push the reviewed branch and main.

### Review
- The release-file test run passed 204 tests and the standalone Debug build passed. Artifacts: `/tmp/mail-notifier-review/release-3.8.0-final.xcresult` and the matching test/build logs.
- The public feed shows 3.8.0, build 36, and the exact note “Some UI cleanup.” The signed DMG and its remote enclosure both have 10,707,259 bytes.
- The original release script stopped after notarization because its old R2 Doppler project no longer exists. The script default was corrected, and its upload steps published the already signed and notarized DMG without changing the build.

## Hover theme selector (cleanup-ui)

### Plan
- [x] Replace the Settings theme menu with a name and right-anchored color circle; show the other theme circles to its left on hover or click.
- [x] Make selection update the stored theme, name, and circle color, then collapse with a spring. Disable motion when Reduce Motion is on.
- [x] Keep the control usable with keyboard and VoiceOver, with a label for each theme and a visible focus state.
- [x] Run the full Xcode test suite and build, inspect collapsed, expanded, and selected states in the running app, and save screenshots.

### Review
- The fresh Xcode test run passed 204 tests, and the standalone Debug build passed. Logs and the test result bundle are under `/tmp/mail-notifier-review/theme-selector-*`.
- The running Settings view showed choices expanding left of the selected circle. Selecting Nerds updated the name and circle, then collapsed the choices. Accessibility listed each theme as a button.
- Captures: `mail-theme-expanded.png` and `mail-theme-selected.png` in the shared screenshots directory. The saved account settings were restored afterward.

### Cases to check
- Moving from the current circle into the choices keeps them open; leaving the control closes them.
- Clicking the current circle opens the choices without hover, and selecting a choice closes them.
- The current circle stays anchored at the right while the choices appear on its left.
- The System theme is distinguishable in both system appearances.
- Keyboard and VoiceOver can open the choices, identify a theme, and select it.
- Reduce Motion disables the bounce.

## Quiet hours (cleanup-ui)

### Plan
- [x] Write the failure cases and tests for local-time quiet-hour boundaries, overnight windows, disabled settings, and equal start/end times.
- [x] Add persisted quiet-hour settings and suppress notification delivery during the selected local-time window while mail checks continue.
- [x] Add an accessible quiet-hours control and start/end time pickers to Settings, with localized labels.
- [x] Verify the full test suite, localization files, build, and live UI; save review artifacts.
- [x] Review behavior and list further feature ideas without implementing them.

### Review
- A fresh isolated `xcodebuild test` passed 204 tests with zero failures. A final standalone `xcodebuild build` passed with the same source files. The logs are `/tmp/mail-notifier-review/quiet-test-final.log` and `/tmp/mail-notifier-review/quiet-build-final.log`. The installed app was restored and relaunched afterward.
- The quiet-hours schedule follows local wall time every day, includes its start, excludes its end, and treats equal times as no interval. Mail checks and unread counts continue. Messages received during quiet hours stay suppressed after a later fetch.
- All 22 locale files passed `plutil -lint`. The new translations need native-speaker review. The Settings toggle and time controls were inspected in the running debug app. Screenshots are in `/Users/prashant/.codex/visualizations/2026/11/08/01a1b9c1-dfc3-7aa1-8a2e-b771e8dc5c85/screenshots`.

### Failure cases to test first
- The feature is off on a fresh install and remains off after a saved choice.
- A daytime window includes its start and excludes its end.
- An overnight window spans midnight and excludes its end.
- Equal start and end times suppress nothing.
- Local wall-clock time follows the supplied calendar and time zone, including a repeated hour at the daylight-saving change.
- Stored minute values outside 0 through 1439 are clamped before use.
- Messages seen during quiet hours stay suppressed when a later fetch includes them again.
- Suppressed identifiers persist across app restarts and older entries are removed at the storage limit.
- Mail that arrived during quiet hours stays silent when the Mac first fetches it after waking.
- A stored time displays identically on a daylight-saving transition day.

## UI cleanup (cleanup-ui)

### Plan
- [x] Simplify the Pretty popover hierarchy and move appearance and Quit into Settings or a secondary menu.
- [x] Reorganize Settings into a clear, single-column layout without removing controls.
- [x] Simplify account status, account actions, and first-run copy while preserving account behavior.
- [x] Check source-level keyboard labels, empty and error states, localization, and the Classic menu.
- [x] Inspect the rendered app and save screenshots.
- [x] Review the diff and report feature ideas separately from the UI cleanup.

### Review
- UI changes are implemented. A fresh `xcodebuild test` passed 204 tests after isolating the test host from the installed app. `xcodebuild build-for-testing` and a final standalone `xcodebuild build` passed. All 22 localization files passed `plutil -lint`; `git diff --check` passed.
- The welcome screen, Settings, quiet-hours controls, and dropdown content were captured from the debug build. The dropdown screenshot shows the actual SwiftUI content in a temporary preview window with demo accounts, so menu bar placement still needs a direct check. The temporary preview code was removed, the normal build passed, and the installed app and saved settings were restored.

## Release 3.7.1 (current)

### Steps
- [x] 1. Add the 3.7.1 changelog entry with Phillip's credit.
- [x] 2. Run the complete local release checks and commit Compact mode.
- [x] 3. Run the signed, notarized, Sparkle-signed shipping pipeline for build 35.
- [x] 4. Verify the live DMG and appcast, commit release metadata, and push once.

### Review
- Apple accepted notarization submissions for the app and DMG, and both staple validations passed.
- The versioned DMG and latest alias are live with the expected 10,673,943-byte size.
- The live appcast matches the local file and the public shortlink reports version 3.7.1, build 35, with Phillip's credit.
- Compact mode is committed as `b13af77`. Release metadata is committed separately and both commits are pushed together.

## Compact mode (current)

### Steps
- [x] 1. Add failing tests for the default, persisted setting, and unread-account filter.
- [x] 2. Add the Compact mode switch above anonymous usage data in General settings.
- [x] 3. Apply the unread-account filter to the Pretty and Classic dropdowns.
- [x] 4. Refresh the Pretty dropdown when the setting changes, show centered Inbox Zero copy there, and show one gray line in Classic mode.
- [x] 5. Add a subtle spring enter and exit transition to account rows in Pretty mode, with Reduce Motion support.
- [x] 6. Regenerate the Xcode project and run the complete test and build checks.

### Review
- Compact mode defaults to off and persists in UserDefaults.
- Pretty mode filters and animates account rows as unread counts change. Reduce Motion keeps a short opacity change without movement.
- Classic mode filters the same accounts and uses the requested disabled Inbox Zero row.
- All 192 tests pass. Every localization file passes `plutil -lint`.
- The Debug build succeeded, and the user confirmed the feature works as requested.

## Drag to reorder accounts, custom account icons that roam (current)

Full design in `~/.claude/plans/radiant-inventing-widget.md`.

### Steps
- [x] 1. Tests: `Tests/AccountIconStoreTests.swift`, `Tests/AccountIconImageTests.swift`,
      reorder cases in `Tests/AccountStoreTests.swift`.
- [x] 2. `Source/Models/AccountIconStore.swift` (KVS + UserDefaults mirror, per-account keys).
- [x] 3. `Source/Utilities/AccountIconImage.swift` (center crop, 128px PNG).
- [x] 4. `ProviderBadge` moves to `SharedComponents.swift`, takes an `Account`, draws the custom icon.
- [x] 5. `AccountView` header: click the badge for Upload Image… / Accept Default.
- [x] 6. `ClassicMenuBuilder` uses the custom icon; `AppDelegate` starts the store and redraws on change.
- [x] 7. `Sidebar` becomes a `List` with `onMove` calling `Accounts.reorder`.
- [x] 8. CHANGELOG 3.7.0 entry, README file tree.
- [x] 9. `xcodegen generate`, quit installed app, `xcodebuild test`, relaunch.
- [x] 10. Run the Debug build and check the Pretty dropdown by hand.

### Review
- 179 tests pass, 21 of them new (icon store, image normalization, reorder).
  The old date-dependent Formatters failure did not show up this run.
- Verified live in the Debug build with synthetic mouse events: dragging the
  third account to the top rewrote the stored order, the Pretty popover
  listed accounts in that order, the header badge menu offered Upload Image…
  and Accept Default, an uploaded 400x240 PNG came back as a 4.4 KB
  center-cropped icon in the sidebar, header, and popover, and Accept Default
  cleared it everywhere. Order and icon were put back afterwards.
- Found during testing: any SwiftUI gesture on a List row blocks `onMove`
  drag on macOS. Selection now goes through `List(selection:)` with `.tag`,
  and an opaque `listRowBackground` hides the system highlight.
- Not checked by hand: the Classic menu style (same store, rebuilt on
  `.accountIconsChanged`), and roaming to a second Mac.

## Mail Notifier Pro: paid multi-account via Polar

Full design in `tasks/paid-accounts-spec.md`. One account free forever, then
**Mail Notifier Pro**: a yearly pay-what-you-want subscription, $1.99 minimum and
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
      Do not skip 10 (a Sync Bar key must be rejected) or 12 (a $1.99 purchase
      must renew at $1.99, not at the $5.99 suggestion).
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
