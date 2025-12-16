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
│   │   ├── StoreKitManager.swift       # In-app purchases
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
│   │   ├── CoffeeView.swift            # Support/donation view
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
├── Info.plist                          # App configuration and URL schemes
├── MailNotifier.entitlements           # App sandbox entitlements
└── MailNotifier.xcodeproj/             # Xcode project
```

## Setup for personal use

Google is an awful company that doesn't believe in or support developers. They force indie developers who want to build email apps to spend $8000 to certify their products. It's absurd and stifles fun, creative innovation.

I plan on paying this extortion to the random company that Google has pre-selected for me to pay my bribe. You are welcome to [donate to my Patreon]() to support independent development, or you can download the app from the Mac App Store and "Buy Me Coffee" from the Settings screen.

If you elect to clone this repo and run this app locally, you will need to go through some things. Since this app requires access to Gmail and Outlook APIs, you must configure your own OAuth credentials.

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

1. Open `MailNotifier.xcodeproj` in Xcode
2. Select the "MailNotifier" scheme
3. Build and run (Cmd+R)

When signing in with Google, you will see an "unverified app" warning since the app is in testing mode. Click "Continue" to proceed (this is safe for personal use with your own credentials).

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

## License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Strategic Nerds, Inc.
