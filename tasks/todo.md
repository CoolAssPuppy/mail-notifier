# Todo

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

### Behavior note
Previews (selecting a sound in Settings/Account) keep using `NSSound` for instant feedback. That is
correct: previews are not notifications and should play regardless of Focus.

Coupling tradeoff (approved): sound now plays only when the banner does. The old "sound without banner"
path is gone, which is required for Focus to govern the sound.

## Add Revolut donate link (done)
- [x] `SettingsView.swift`: add "(Revolut)" row -> https://revolut.me/coolasspuppy after "Buy me coffee"
