//
//  URLRouter.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

/// Routes incoming URLs to the appropriate handler based on URL scheme.
enum URLRouter {
    static func route(url: URL) {
        switch true {
        case url.scheme == "mailnotifier", url.host == "preferences":
            Log.app.info("Routing to preferences")
            NotificationCenter.default.post(name: .openPreferencesWindow, object: nil)
        case url.scheme == GoogleOAuthClient.redirectScheme, url.path == "/oauthredirect":
            Log.app.info("Routing to Google OAuth")
            GoogleOAuthClient.shared.resumeAuthFlow(url: url)
        case url.scheme == OutlookOAuthClient.redirectScheme, url.host == "auth":
            Log.app.info("Routing to Outlook OAuth")
            OutlookOAuthClient.shared.resumeAuthFlow(url: url)
        case url.scheme == "mailto":
            Log.app.info("Routing to mailto handler")
            NotificationCenter.default.post(name: .mailToReceived, object: url)
        default:
            Log.app.warning("No handler for URL with scheme: \(url.scheme ?? "nil")")
        }
    }
}
