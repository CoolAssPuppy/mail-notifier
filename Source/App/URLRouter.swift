//
//  URLRouter.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

/// Routes incoming URLs to the appropriate handler based on URL scheme.
enum URLRouter {
    enum Route: Equatable {
        case preferences
        case googleOAuth
        case outlookOAuth
        case mailTo
    }

    static func route(url: URL) {
        guard let route = route(for: url) else {
            Log.app.warning("No handler for URL with scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil"), path: \(url.path)")
            return
        }

        switch route {
        case .preferences:
            Log.app.info("Routing to preferences")
            NotificationCenter.default.post(name: .openPreferencesWindow, object: nil)
        case .googleOAuth:
            Log.app.info("Routing to Google OAuth")
            GoogleOAuthClient.shared.resumeAuthFlow(url: url)
        case .outlookOAuth:
            Log.app.info("Routing to Outlook OAuth")
            OutlookOAuthClient.shared.resumeAuthFlow(url: url)
        case .mailTo:
            Log.app.info("Routing to mailto handler")
            NotificationCenter.default.post(name: .mailToReceived, object: url)
        }
    }

    static func route(for url: URL) -> Route? {
        if isPreferencesURL(url) { return .preferences }
        if isGoogleOAuthCallback(url) { return .googleOAuth }
        if isOutlookOAuthCallback(url) { return .outlookOAuth }
        if url.scheme?.lowercased() == "mailto" { return .mailTo }
        return nil
    }

    static func isPreferencesURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "mailnotifier"
            && url.host?.lowercased() == "preferences"
    }

    static func isGoogleOAuthCallback(_ url: URL) -> Bool {
        url.scheme == GoogleOAuthClient.redirectScheme
            && url.host?.isEmpty != false
            && url.path == "/oauthredirect"
    }

    static func isOutlookOAuthCallback(_ url: URL) -> Bool {
        url.scheme == OutlookOAuthClient.redirectScheme
            && url.host?.lowercased() == "auth"
            && (url.path == "/" || url.path.isEmpty)
    }
}
