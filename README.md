# Mail Notifr (formerly Gmail Notifr) #

A Gmail Notifier for macOS

## Mail Notifr sunset on March 8th, 2024.

**As this app needs to access Gmail restricted APIs, it's required to complete a CASA security assessment, which is a progress I could NOT get through.**

**I've decided to make the end of its service. Sorry, and thank you.**

![screenshot](screenshot.png)

[Mail Notifr](https://bit.ly/gmail-notifr-store) features:

* Support multiple Google Accounts (OAuth 2.0).
* Separate check and notification setting for each account.
* Preferred browser setting for each account.
* Support Google hosted account.
* Check mail at a specified interval.
* Notification Center &amp; sound notifications.
* Small &amp; fast.
* No background daemon processes installed as Google's official notifier.
* Open Source!
* Free! Install from [Mac App Store](https://bit.ly/gmail-notifr-store).

## Requirements ##

* 2.0.0+: macOS 11 Big Sur or later.
* 1.3.5 and below: macOS 10.8 or later.

## Note ##

Mail Notifr was originally written in RubyCocoa, then MacRuby, then Objective-C, and recently Swift.

* The [MacRuby implementation](https://github.com/ashchan/gmail-notifr) repository remains. I also created a [macruby](https://github.com/ashchan/mail-notifr/tree/macruby) branch.

* The RubyCocoa implementation's on the [rubycocoa](https://github.com/ashchan/mail-notifr/tree/rubycocoa) branch.

## Updates, Changelog &amp; Feedback ##

Feedback is welcome! Leave a message on the [feedback](https://blog.ashchan.com/archive/2008/10/29/gmail-notifr-changelog/) page, or create a github [issue](https://github.com/ashchan/mail-notifr/issues), or tweet the author [@ashchan](https://twitter.com/ashchan).

View the full [changelog](CHANGELOG.md).

Visit [project home page](https://ashchan.com/projects/gmail-notifr) for more information.

## License ##

[The MIT License](LICENSE)

**Binary or modification is NOT allowed to submit to Apple App Store without written permission!**

Copyright (c) 2008 - 2021 [James Chen](https://ashchan.com/) ([@ashchan](https://twitter.com/ashchan))

## Personal Use Setup

Since Mail Notifr has been sunset due to Google API restrictions, you can still set it up for personal use by following these steps:

### 1. Google Cloud Console Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project
3. Enable the Gmail API:
   - Go to "APIs & Services" → "Library"
   - Search for "Gmail API"
   - Click "Enable"
4. Create OAuth Credentials:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth Client ID"
   - Choose "Desktop Application" as the application type
   - Give it a name (e.g., "Mail Notifr Personal")
   - Copy both the Client ID and Client Secret for later use

### 2. OAuth Consent Screen Setup
1. Go to "APIs & Services" → "OAuth consent screen"
2. Choose "External" user type
3. Fill in required fields:
   - App name
   - User support email
   - Developer contact information
4. Add scopes:
   - `https://www.googleapis.com/auth/gmail.readonly`
   - `https://www.googleapis.com/auth/gmail.metadata`
5. Add your Google account email as a test user
6. Leave the app in "Testing" status

### 3. Code Modifications
1. Update Info.plist URL Scheme:
   - Open the project in Xcode
   - Select the project in navigator
   - Select "Mail Notifr" target
   - Go to "Info" tab
   - Under "URL Types", replace the existing URL scheme with:   ```
   com.googleusercontent.apps.YOUR_CLIENT_ID   ```
   (Remove the .apps.googleusercontent.com portion from your client ID)

2. Update OAuthClient.swift:   ```swift
   static let clientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"
   static let clientSecret = OAuthSecret.secret
   static let redirectURL = "com.googleusercontent.apps.YOUR_CLIENT_ID:/oauthredirect"   ```

3. Replace OAuthSecret.swift contents with:   ```swift
   struct OAuthSecret {
       static let secret = "YOUR_CLIENT_SECRET"
   }   ```

### 4. Build and Run
1. Clean the build (Xcode → Product → Clean Build Folder)
2. Build and run the project
3. When prompted to sign in with Google:
   - You'll see a warning about the app being unverified
   - Click "Continue" since you're a test user
   - Grant the requested permissions

### Notes
- This setup is for personal use only
- Only Google accounts added as test users can authenticate
- The app will need to be rebuilt if the OAuth credentials expire
- Keep your Client ID and Client Secret secure
- Do not distribute the built app with your personal OAuth credentials

### Hotmail / Outlook Setup
To use Microsoft accounts:
1. Create an application in the [Azure Portal](https://portal.azure.com/).
2. Enable the Microsoft Graph **Mail.Read** permission.
3. Add a native redirect URI that matches `OutlookOAuthClient.redirectURL` in the code.
4. Put your client ID and secret in `OutlookOAuthClient.swift` and `OutlookOAuthSecret.swift`.
5. Add the same URL scheme to Info.plist.
6. Build and run then choose **Add Outlook Account**.

### Token Expiration
Refresh tokens issued while the Google app is in testing mode expire after about seven days.
If the notifier stops working, open preferences and reauthorize the account.

### Troubleshooting
If you get an "invalid_client" error:
- Verify your Client ID and Client Secret are correctly copied
- Ensure your Google account is added as a test user
- Check that the URL scheme in Info.plist matches your Client ID
- Clean and rebuild the project
