//
//  CrashReporting.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation
import Sentry

/// Crash reports through Sentry, plus release-health sessions.
///
/// The DSN comes from Info.plist (`SENTRY_DSN`), injected by
/// `scripts/release.sh` from Doppler. A dev build or a fork carries the
/// unsubstituted `$(SENTRY_DSN)` placeholder and stays off. It also stays off
/// when the person has turned off "Send anonymous usage data".
enum CrashReporting {
    static func usableDSN(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }

    /// Cocoa default: `bundleIdentifier@version+build`. Must match the name
    /// `sentry-cli debug-files upload` creates from the archive, or sessions
    /// land on a different release than the dSYMs.
    static func releaseName(identifier: String?, version: String?, build: String?) -> String? {
        guard let identifier, !identifier.isEmpty,
              let version, !version.isEmpty else { return nil }
        if let build, !build.isEmpty {
            return "\(identifier)@\(version)+\(build)"
        }
        return "\(identifier)@\(version)"
    }

    static func dist(_ build: String?) -> String? {
        guard let build = build?.trimmingCharacters(in: .whitespacesAndNewlines),
              !build.isEmpty else { return nil }
        return build
    }

    static var environment: String {
        #if DEBUG
        "debug"
        #else
        "production"
        #endif
    }

    static func configure(_ options: Options,
                          dsn: String,
                          bundle: Bundle = .main) {
        options.dsn = dsn
        options.sendDefaultPii = false
        options.enableAutoSessionTracking = true
        options.tracesSampleRate = 0.0
        options.environment = environment
        let identifier = bundle.bundleIdentifier
            ?? bundle.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) as? String
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
        if let name = releaseName(identifier: identifier, version: version, build: build) {
            options.releaseName = name
        }
        if let buildNumber = dist(build) {
            options.dist = buildNumber
        }
    }

    static func start() {
        guard Telemetry.isOptedIn,
              let dsn = usableDSN(Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String) else {
            return
        }
        SentrySDK.start { options in
            configure(options, dsn: dsn)
        }
        // Auto session tracking only starts a session when NSApplication is
        // active. This is a menu-bar accessory app, so it almost never is,
        // and Sentry showed a dSYM-created release with no sessions. One
        // startSession() per launch is the session for this run; the auto
        // tracker still ends it on quit and marks a crash on the next launch.
        SentrySDK.startSession()
    }

    static func stop() {
        SentrySDK.close()
    }
}
