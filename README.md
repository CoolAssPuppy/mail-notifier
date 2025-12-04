# Mail Notifier

A lightweight macOS menu bar application that monitors Gmail and Outlook accounts for new messages and displays notifications.

## Credits

This project is a fork of [Gmail Notifr](https://ashchan.com/projects/gmail-notifr) by [James Chen](https://ashchan.com/) ([@ashchan](https://github.com/ashchan)). The original project was sunset in March 2024 due to the complexity of Google's CASA security assessment requirements for Gmail API access.

Original repository: [https://github.com/ashchan/mail-notifr](https://github.com/ashchan/mail-notifr)

## License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2008-2021 James Chen
Copyright (c) 2026 Strategic Nerds

## Features

### Original features

- Support for multiple Google (Gmail) accounts
- OAuth 2.0 authentication
- Per-account settings for check interval, notifications, and sounds
- Configurable browser for opening mail links
- Menu bar icon with unread count
- Native macOS app built with SwiftUI
- Launch at login support
- Localized in English, Japanese, and Chinese (Simplified)

### New in this fork

- Outlook and Microsoft account support
- Notifications for VIP senders
- Rewritten and revamped mail checking algorithm
- Glass effect and modern UI
- 27 notification sounds (14 system sounds + 13 custom sounds)

## Requirements

- macOS 11 Big Sur or later
- Xcode 15+ (for building)

## Project structure

```
mail-notifier/
├── Source/                     # Swift source files
│   ├── MailNotifierApp.swift   # App entry point and URL scheme handling
│   ├── AppDelegate.swift       # Menu bar setup and app lifecycle
│   ├── AppDelegate+Menu.swift  # Menu bar menu construction
│   ├── Account.swift           # Account model and keychain storage
│   ├── AccountView.swift       # Individual account settings view
│   ├── AppSettings.swift       # Global app settings
│   ├── Browser.swift           # Browser detection and launching
│   ├── MainView.swift          # Main window container
│   ├── Message.swift           # Email message model
│   ├── MessageFetcher.swift    # Gmail/Outlook API fetching logic
│   ├── OAuthClient.swift       # Google OAuth implementation
│   ├── OAuthSecret.swift       # Google client secret (generated)
│   ├── OutlookOAuthClient.swift # Microsoft OAuth implementation
│   ├── OutlookOAuthSecret.swift # Microsoft client secret
│   ├── SettingsView.swift      # Global settings panel
│   ├── Sidebar.swift           # Account list sidebar
│   ├── Sound.swift             # Notification sound definitions
│   └── WelcomeView.swift       # First-run welcome screen
│
├── Resources/
│   ├── Credits.html            # About box credits
│   ├── Sounds/                 # Custom notification sounds (AIFF)
│   ├── en.lproj/               # English localization
│   ├── ja.lproj/               # Japanese localization
│   └── zh-Hans.lproj/          # Chinese (Simplified) localization
│
├── Images.xcassets/
│   ├── AppIcon.appiconset/     # Application icon
│   ├── Colors/                 # Color assets
│   └── Menu Icons/             # Menu bar icons
│
├── vendors/
│   ├── generateSecret.sh       # Build script for OAuth secrets
│   ├── gyb                     # GYB template processor
│   └── gyb.py                  # GYB Python implementation
│
├── Info.plist                  # App configuration and URL schemes
├── MailNotifier.entitlements   # App sandbox entitlements
└── MailNotifier.xcodeproj/     # Xcode project
```

## Setup for personal use

Since this app requires access to Gmail and Outlook APIs, you must configure your own OAuth credentials.

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
   - Add your Google account as a test user
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
4. Add a native redirect URI matching the value in `OutlookOAuthClient.swift`
5. Copy the Application (client) ID

### Configure the app

1. Update `Source/OAuthClient.swift`:
   ```swift
   static let clientID = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
   static let redirectURL = "com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID:/oauthredirect"
   ```

2. Update `Source/OAuthSecret.swift`:
   ```swift
   struct OAuthSecret {
       static let secret = "YOUR_GOOGLE_CLIENT_SECRET"
   }
   ```

3. Update `Source/OutlookOAuthClient.swift` with your Microsoft client ID

4. Update `Info.plist` URL schemes to match your Google client ID:
   - The URL scheme should be: `com.googleusercontent.apps.YOUR_CLIENT_ID`

### Build and run

1. Open `MailNotifier.xcodeproj` in Xcode
2. Select the "MailNotifier" scheme
3. Build and run (Cmd+R)

When signing in with Google, you will see an "unverified app" warning since the app is in testing mode. Click "Continue" to proceed (this is safe for personal use with your own credentials).

### Notes

- Google OAuth tokens in testing mode expire after approximately 7 days. Reauthorize accounts from preferences when needed.
- Only Google accounts added as test users in Google Cloud Console can authenticate.
- Keep your OAuth credentials secure and never commit them to version control.

## Adding custom sounds

Place AIFF audio files in `Resources/Sounds/` and add corresponding cases to the `Sound` enum in `Source/Sound.swift`. The display name is derived from the filename (e.g., `my-sound.aiff` displays as "My Sound").

## Dependencies

The app uses Swift Package Manager for dependencies:

- [GTMAppAuth](https://github.com/google/GTMAppAuth) - Google OAuth
- [AppAuth](https://github.com/openid/AppAuth-iOS) - OAuth 2.0 client
- [GoogleAPIClientForREST](https://github.com/google/google-api-objectivec-client-for-rest) - Gmail API
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - Keychain wrapper
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) - Login item helper
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global keyboard shortcuts
