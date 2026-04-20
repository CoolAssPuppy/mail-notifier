# Mail Notifier

A lightweight macOS menu bar application that monitors Gmail and Outlook accounts for new messages and displays notifications.

## About this project

This project was inspired by [Gmail Notifr](https://ashchan.com/projects/gmail-notifr) by [James Chen](https://ashchan.com/) ([@ashchan](https://github.com/ashchan)), which was sunset in March 2024 due to the complexity of Google's CASA security assessment requirements for Gmail API access.

Mail Notifier is a ground-up rewrite designed for modern macOS development best practices and built to pass Google's CASA (Cloud Application Security Assessment) review. While it shares the same general purpose as the original project, the codebase has been completely rewritten using contemporary SwiftUI patterns, modern Swift concurrency, and a modular architecture.

## Features

- Support for multiple Google (Gmail) and Microsoft (Outlook) accounts
- OAuth 2.0 authentication for both providers
- Per-account settings for check interval, notifications, and sounds
- VIP sender list with custom notification sounds
- Configurable browser for opening mail links
- Menu bar icon with optional unread count badge
- Global keyboard shortcuts for quick actions
- Native macOS app built with SwiftUI
- Launch at login support
- Modern glass effect UI
- 27 notification sounds (14 sounds from the original app + 13 custom sounds)
- Localized in 22 languages

## Requirements

- macOS 14.6 Sonoma or later
- Xcode 15+ (for building)

## Project structure

```
mail-notifier/
├── Source/
│   ├── App/
│   │   ├── MailNotifierApp.swift       # App entry point
│   │   ├── AppDelegate.swift           # Menu bar setup and app lifecycle
│   │   ├── AppDelegate+Menu.swift      # Menu bar menu construction
│   │   └── AppSettings.swift           # Global app settings
│   │
│   ├── Models/
│   │   ├── Account.swift               # Account model and keychain storage
│   │   ├── Browser.swift               # Browser detection and launching
│   │   ├── Message.swift               # Email message model
│   │   ├── Sound.swift                 # Notification sound definitions
│   │   └── VIP.swift                   # VIP sender model
│   │
│   ├── Services/
│   │   ├── MessageFetcher.swift        # Gmail/Outlook API fetching logic
│   │   ├── LaunchAtLoginManager.swift  # Login item management
│   │   ├── UpdaterManager.swift        # Sparkle auto-update wrapper
│   │   └── OAuth/
│   │       ├── GoogleOAuthClient.swift     # Google OAuth implementation
│   │       └── OutlookOAuthClient.swift    # Microsoft OAuth implementation
│   │
│   ├── Utilities/
│   │   ├── Logger.swift                # Logging utilities
│   │   └── NotificationNames.swift     # Centralized notification names
│   │
│   ├── Views/
│   │   ├── MainView.swift              # Main window with NavigationSplitView
│   │   ├── Sidebar.swift               # Account list sidebar
│   │   ├── AccountView.swift           # Individual account settings
│   │   ├── SettingsView.swift          # Global settings panel
│   │   ├── WelcomeView.swift           # First-run welcome screen
│   │   └── Components/
│   │       └── SharedComponents.swift  # Reusable UI components
│   │
│   └── OAuthSecret.swift               # OAuth client secrets (generated from xcconfig)
│
├── Secrets.xcconfig.example            # Template for OAuth credentials
├── Secrets.xcconfig                    # Your OAuth credentials (gitignored)
│
├── Resources/
│   ├── Sounds/                         # Custom notification sounds (AIFF)
│   ├── en.lproj/                       # English localization
│   ├── en-GB.lproj/                    # British English
│   ├── ja.lproj/                       # Japanese
│   ├── zh-Hans.lproj/                  # Chinese (Simplified)
│   ├── zh-Hant.lproj/                  # Chinese (Traditional)
│   ├── ko.lproj/                       # Korean
│   ├── fr.lproj/                       # French
│   ├── de.lproj/                       # German
│   ├── es.lproj/                       # Spanish
│   ├── pt-BR.lproj/                    # Portuguese (Brazil)
│   ├── pt-PT.lproj/                    # Portuguese (Portugal)
│   ├── it.lproj/                       # Italian
│   ├── nl.lproj/                       # Dutch
│   ├── sv.lproj/                       # Swedish
│   ├── nb.lproj/                       # Norwegian
│   ├── da.lproj/                       # Danish
│   ├── pl.lproj/                       # Polish
│   ├── cs.lproj/                       # Czech
│   ├── uk.lproj/                       # Ukrainian
│   ├── tr.lproj/                       # Turkish
│   ├── hi.lproj/                       # Hindi
│   └── tlh.lproj/                      # Klingon
│
├── Images.xcassets/
│   ├── AppIcon.appiconset/             # Application icon
│   ├── Colors/                         # Color assets
│   └── Menu Icons/                     # Menu bar icons
│
├── vendors/
│   ├── generateSecret.sh               # Build script for OAuth secrets
│   ├── gyb                             # GYB template processor
│   └── gyb.py                          # GYB Python implementation
│
├── scripts/
│   ├── debug.sh                        # Build + launch a local Debug copy
│   ├── release.sh                      # One-shot Developer ID release + upload
│   ├── build-dmg.sh                    # DMG packaging + notarization + Sparkle signing
│   └── export-options.plist            # xcodebuild export config (method: developer-id)
│
├── dmg-assets/
│   └── README.md                       # How to generate the DMG background
│
├── dist/
│   └── appcast.xml                     # Sparkle appcast (uploaded by release.sh)
│
├── project.yml                         # xcodegen config (source of truth)
├── Info.plist                          # App configuration, URL schemes, Sparkle keys
├── MailNotifier.entitlements           # Entitlements (empty; app is unsandboxed)
├── SPARKLE.md                          # One-time Sparkle + Dub.co setup
└── MailNotifier.xcodeproj/             # Generated by xcodegen (do not hand-edit)
```

## Installing the release build

Mail Notifier is distributed as a signed, notarized DMG. To install:

1. Download the latest DMG: [coolasspuppy.com/mail-notifier-updates](https://coolasspuppy.com/mail-notifier-updates) (redirects to the current appcast; the newest `<enclosure url>` is the DMG).
2. Open the DMG and drag `Mail Notifier.app` to `/Applications`.
3. Launch it. macOS will verify the notarization ticket the first time you open the app.

Once installed, the app checks for updates automatically once a day, and you can trigger a manual check from the status-bar icon > "Check for Updates…" or from Settings > Updates.

If you previously had the Mac App Store build installed, delete that one from `/Applications` before dragging the DMG build in — the App Store version and the Developer ID version can't coexist under the same bundle identifier.

## Support independent development

Google forces indie developers who want to build email apps to spend roughly $8,000 a year on the mandatory CASA security assessment. This app depends on your generosity to keep going. If Mail Notifier is useful to you, consider tipping via [Venmo to @coolasspuppy](https://venmo.com/coolasspuppy).

## Setup for personal use

If you want to clone this repo and run the app locally, you'll need your own Google and Microsoft OAuth credentials since this app reads Gmail and Outlook APIs.

### Google (Gmail) setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project
3. Enable the Gmail API:
   - Navigate to "APIs & Services" then "Library"
   - Search for "Gmail API" and enable it
4. Configure OAuth consent screen:
   - Go to "APIs & Services" then "OAuth consent screen"
   - Choose "External" user type
   - Fill in required fields (app name, support email, developer contact)
   - Add scope: `https://www.googleapis.com/auth/gmail.readonly`
   - Add your Google account as a test user (this is important!)
5. Create OAuth credentials:
   - Go to "APIs & Services" then "Credentials"
   - Click "Create Credentials" then "OAuth Client ID"
   - Choose "iOS" as application type
   - Set bundle ID to `com.strategicnerds.MailNotifierApp`
   - Copy the Client ID and Client Secret

### Microsoft (Outlook) setup

1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to "App registrations" and create a new registration
3. Add Microsoft Graph `Mail.Read` permission
4. Add a native redirect URI matching the value in `Source/Services/OAuth/OutlookOAuthClient.swift`
5. Copy the Application (client) ID

### Configure the app

1. Copy `Secrets.xcconfig.example` to `Secrets.xcconfig`:
   ```bash
   cp Secrets.xcconfig.example Secrets.xcconfig
   ```

2. Edit `Secrets.xcconfig` with your OAuth credentials:
   ```
   GOOGLE_CLIENT_ID = your-google-client-id.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET = your-google-client-secret
   OUTLOOK_CLIENT_ID = your-outlook-client-id
   OUTLOOK_CLIENT_SECRET = your-outlook-client-secret
   ```

3. Update `Info.plist` URL schemes to match your Google client ID:
   - Find the URL scheme entry and update it to: `com.googleusercontent.apps.YOUR_CLIENT_ID`
   - Replace `YOUR_CLIENT_ID` with just the first part of your Google client ID (before `.apps.googleusercontent.com`)

### Build and run

The project is generated from `project.yml` by [xcodegen](https://github.com/yonaskolb/XcodeGen). You do not need to open Xcode to build, run, or release.

Install the tooling once:

```bash
brew install xcodegen create-dmg
```

Then, from the repo root:

```bash
# Build a Debug copy and launch it
./scripts/debug.sh

# Build only, don't launch
./scripts/debug.sh --no-launch
```

The script runs `xcodegen generate`, builds with `xcodebuild`, and copies the `.app` to `dist/debug/Mail Notifier.app`. If you'd rather open Xcode anyway, run `xcodegen generate` first, then open `MailNotifier.xcodeproj`.

When signing in with Google, you'll see an "unverified app" warning since the app is in testing mode. Click "Continue" to proceed (safe for personal use with your own credentials).

### Cut a release

See [SPARKLE.md](SPARKLE.md) for the one-time Sparkle signing-key and Dub.co shortlink setup. Then releases are one command:

```bash
./scripts/release.sh 3.1.0 "<li>What changed.</li><li>Another thing.</li>"
```

This bumps `project.yml`, archives, exports a Developer ID-signed `.app`, notarizes and staples it, builds a signed + notarized + Sparkle-signed DMG, and uploads the DMG plus the updated appcast to the `downloads` Supabase bucket. Commit `project.yml` and `dist/appcast.xml` after the script finishes.

### Sparkle private key backup

The Ed25519 private key that signs every Mail Notifier update lives in the login keychain under account `com.strategicnerds.MailNotifierApp`. A PEM copy is stored in **Doppler** (`agent-server/prd`, secret `SPARKLE_PRIVATE_KEY`) so releases can still be cut from a fresh machine if this laptop dies.

If the key is lost entirely and no backup exists, every installed copy of the app is permanently stranded — Sparkle has no key-rotation mechanism.

To restore it on a new machine:

```bash
doppler secrets get SPARKLE_PRIVATE_KEY \
  --project agent-server --config prd --plain \
  > /tmp/mail-notifier-sparkle-private.pem

~/Library/Developer/Xcode/DerivedData/MailNotifier-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account com.strategicnerds.MailNotifierApp \
  -f /tmp/mail-notifier-sparkle-private.pem

rm -P /tmp/mail-notifier-sparkle-private.pem
```

Verify the restore produced the right pair by running `generate_keys --account com.strategicnerds.MailNotifierApp -p` and comparing the printed public key to `SUPublicEDKey` in `Info.plist`. See [SPARKLE.md](SPARKLE.md) for the full setup walkthrough.

### Notes

- Google OAuth tokens in testing mode expire after approximately 7 days. Reauthorize accounts from preferences when needed.
- Only Google accounts added as test users in Google Cloud Console can authenticate.
- `Secrets.xcconfig` is gitignored to prevent accidentally committing your credentials. Keep this file secure.

## Adding custom sounds

Place AIFF audio files in `Resources/Sounds/` and add corresponding cases to the `Sound` enum in `Source/Models/Sound.swift`. The display name is derived from the filename (e.g., `my-sound.aiff` displays as "My Sound").

## Dependencies

The app uses Swift Package Manager for dependencies:

- [GTMAppAuth](https://github.com/google/GTMAppAuth) - Google OAuth
- [AppAuth](https://github.com/openid/AppAuth-iOS) - OAuth 2.0 client
- [GoogleAPIClientForREST](https://github.com/google/google-api-objectivec-client-for-rest) - Gmail API
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - Keychain wrapper
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global keyboard shortcuts
- [Sparkle](https://sparkle-project.org) - Auto-updates

## License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Strategic Nerds, Inc.
