# Sparkle auto-update setup

Mail Notifier ships with [Sparkle 2](https://sparkle-project.org). Users get "Check for Updates…" in the status-bar menu and in Settings > Updates, plus daily automatic checks.

Appcast and release DMGs live in the existing Supabase `downloads` bucket on project `hlwjnusdotqtmtwrjidu` (shared with Agent Server, different filenames). The appcast URL is fronted by a Dub.co shortlink so the feed location can be moved later without re-shipping the app.

URLs:

- **Feed (baked into the app)**: `https://coolasspuppy.com/mail-notifier-updates` (Dub shortlink)
- **Appcast destination**: `https://hlwjnusdotqtmtwrjidu.supabase.co/storage/v1/object/public/downloads/mail-notifier-appcast.xml`
- **DMG pattern**: `https://hlwjnusdotqtmtwrjidu.supabase.co/storage/v1/object/public/downloads/MailNotifier-<version>.dmg`

Do steps 1 through 5 once. Then step 6 on every release.

## 1. Generate the signing key (one time, irreversible)

Sparkle's `generate_keys` tool creates an Ed25519 key pair. The private key lives in the macOS keychain. **If you lose it, every installed copy of the app is permanently stranded** because it can no longer verify new updates. There is no recovery.

If you already have a Sparkle private key from another project (e.g. Agent Server), **do not reuse it** for Mail Notifier. Each app should have its own key so a compromise in one doesn't let an attacker push fake updates to another.

After running the debug script (or opening the project in Xcode) once so SPM resolves Sparkle, the tool is at:

```
~/Library/Developer/Xcode/DerivedData/MailNotifier-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```

Run it with a keychain-account name specific to this app so it doesn't collide with other Sparkle keys:

```bash
cd ~/Library/Developer/Xcode/DerivedData/MailNotifier-*/SourcePackages/artifacts/sparkle/Sparkle/bin
./generate_keys --account com.strategicnerds.MailNotifierApp
```

It will:
- Create a new key pair on first run, or print the existing public key on later runs.
- Store the private key in the login keychain under "Private key for signing Sparkle updates" with account `com.strategicnerds.MailNotifierApp`.
- Print the base64 **public** key to stdout.

`sign_update` needs to know which account to use, since you may have several. The release script already passes `--account com.strategicnerds.MailNotifierApp` to `sign_update`, so no further action is needed once the key exists in Keychain.

**Back up the private key now.** Export from Keychain Access to a `.p12` and store it in 1Password.

Copy the public key that `generate_keys` printed. You'll paste it in step 4.

## 2. Confirm the Supabase bucket

The `downloads` bucket on project `hlwjnusdotqtmtwrjidu` already hosts Agent Server artifacts and is public. No new bucket needed. Upload this initial appcast via the dashboard (Storage > downloads > Upload file) as `mail-notifier-appcast.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Mail Notifier</title>
    <link>https://hlwjnusdotqtmtwrjidu.supabase.co/storage/v1/object/public/downloads/mail-notifier-appcast.xml</link>
    <description>Mail Notifier updates</description>
    <language>en</language>
  </channel>
</rss>
```

(This is the same file checked into `dist/appcast.xml`.)

Verify by opening the URL in a browser — you should see the XML.

## 3. Create the Dub.co shortlink

Create it once in the Dub dashboard:

- **Short URL**: `https://coolasspuppy.com/mail-notifier-updates`
- **Destination URL**: `https://hlwjnusdotqtmtwrjidu.supabase.co/storage/v1/object/public/downloads/mail-notifier-appcast.xml`

Settings:
- Cloaking/frame: **OFF** (Sparkle needs a plain HTTP redirect, not an iframe wrapper).
- Password: **OFF**.
- Link expiration: **OFF**.

Test:

```bash
curl -sI "https://coolasspuppy.com/mail-notifier-updates" | grep -i '^location:'
```

You should see a `location:` header pointing at the Supabase URL above.

**This slug is baked into every shipped copy of the app and cannot be changed.** You can repoint the destination URL later. You cannot change the slug.

## 4. Paste the public key into Info.plist

Edit `Info.plist`.

Replace the placeholder with the base64 public key from step 1:

```xml
<key>SUPublicEDKey</key>
<string>PASTE_BASE64_PUBLIC_KEY_HERE</string>
```

`SUFeedURL` is already `https://coolasspuppy.com/mail-notifier-updates`. Do not point it at the raw Supabase URL.

Commit that change.

## 5. Register the notarytool keychain profile

```bash
xcrun notarytool store-credentials "mail-notifier" \
  --apple-id "you@example.com" \
  --team-id "955GSY56UT" \
  --password "app-specific-password"
```

This lets the release script notarize without prompting. Use an [app-specific password](https://support.apple.com/en-us/HT204397) from appleid.apple.com, not your Apple ID password.

## 6. Release flow (every release)

```bash
./scripts/release.sh 3.1.0 "<li>First Developer ID release.</li><li>Auto-updates via Sparkle.</li>"
```

The script:
1. Bumps `MARKETING_VERSION` to the argument and increments `CURRENT_PROJECT_VERSION`.
2. Regenerates the Xcode project via `xcodegen`.
3. Archives + exports a Developer ID-signed `.app`.
4. Notarizes + staples the `.app`.
5. Builds a signed + notarized + stapled DMG and Sparkle-signs it.
6. Pulls the Supabase service-role key from Doppler (`agent-server/prd`).
7. Uploads the DMG and the updated `dist/appcast.xml` to the `downloads` bucket.
8. Verifies the feed via the Dub shortlink.

Commit `project.yml` and `dist/appcast.xml` after a successful release.

### Verify end-to-end

On a machine running a previous version:

1. Status bar icon > "Check for Updates…"
2. You should see the update prompt with your release notes.
3. Let it download and install.

If the check says "You're up to date", something is off:
- `CURRENT_PROJECT_VERSION` didn't actually increase in the committed `project.yml`.
- `pubDate` is malformed in the appcast, so Sparkle discarded the item.
- Dub shortlink is returning HTML instead of a redirect (cloaking got turned on).

If the download fails signature verification, the Ed25519 key in Keychain doesn't match `SUPublicEDKey` in the shipped `Info.plist`, or the DMG was modified after `sign_update` ran.

## Notes

- Do not amend released `<item>` entries. If you ship a bad build, bump the version again.
- Never rotate the Dub shortlink slug. You can repoint the destination URL as often as you want.
- Never rotate the Ed25519 key unless you're willing to manually reach every user. There is no key rotation mechanism in Sparkle.
- Sparkle's XPC services are embedded in the SPM product; the app is unsandboxed so no extra entitlements are needed.
- The DMG must itself be signed + notarized + stapled, not just the `.app` inside. Sparkle verifies notarization before mounting.
