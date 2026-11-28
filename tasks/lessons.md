# Lessons

## Verify telemetry configuration in the signed package
2026-11-28: Store builds 42 and 43 linked both SDKs but omitted their Doppler values. Preserve PostHog and Sentry unless removal is requested, verify both values in the final signed package without printing them, and match the privacy disclosure to the resulting behavior.

## Keep optional support separate from access
The Mac App Store build is free, with a consumable tip in Settings. Keep StoreKit out of onboarding, mail checks, and notifications. Preserve the independent license path and leave the old App Store Connect draft alone until the owner decides what to do with it.

## Check small motion at playback size
2026-11-27: Frame changes alone do not make an animation readable. Check the exact export at normal speed, and use decoded frames to measure the movement against the parts meant to stay still.

## Time each caption to the alert
2026-11-27: In the internal notification draft, keep only the app name and one caption outside the illustrated alerts. Let captions change with the arrivals, and put the production disclaimer in the review note.

## Lead with the product payoff
2026-11-27: For Mail Notifier, the creative hero is the macOS alert while other apps are closed. Keep provider-branded motion graphics distinct from captured macOS alerts, and verify privacy claims before publication.

## Test the opening before cutting the whole preview
2026-11-27: When the Store preview direction is rejected, make short, visually distinct opening studies for approval before editing another full cut. Use real Demo Mode UI and distinguish it from a native notification.

## Watch the rendered video references first
2026-11-27: For Store previews, use the approved FutureNerds videos as motion references, then cut around real app actions. Use captions to support the footage rather than turning the feature list into slides.

## Keep the Store review demo available
2026-11-27: The Store build needs the screenshot demo for possible App Review use. Isolate synthetic mail at the provider boundary without granting StoreKit access or touching real credentials.

## Keep Store pricing in sync
2026-11-27: When the owner changes the target price, update the Store plan and setup instructions together. Keep older distribution pricing separate and distinguish the requested price from the price verified in App Store Connect.

## Respect explicit build-only scope
2026-11-27: When the owner waives the feasibility check and separate test phase, implement and compile first. Keep unverified release risks visible and do not upload or change distribution.

## Never rewrite a file you have only partly read
2026-09-12: rewrote `tasks/todo.md` after reading its first 40 lines and
dropped 147 lines of project history. Caught it from `git diff --stat` and
restored from `HEAD`. Rule: prepend or edit with a targeted replacement; a
full `Write` needs the whole file in context first.

## Verify drag and drop live, not by reading the code
2026-09-12: `List` + `onMove` compiled, rendered, and did nothing, because
the row's tap gesture swallowed the mouse-down. Synthetic CGEvent drags
against the running Debug build found it; a code read never would have.

## Check the full animation path inside its card
2026-11-08: The selected theme circle could overshoot the Appearance card during
its spring return even though the open and closed states fit. Rule: inspect the
motion itself, keep enough space around its endpoint, and clip the card when
animated children must remain inside it.
