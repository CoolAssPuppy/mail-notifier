//
//  CrashReporting.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation
import Sentry

/// Crash reports through Sentry.
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

    static func start() {
        guard Telemetry.isOptedIn,
              let dsn = usableDSN(Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String) else {
            return
        }
        SentrySDK.start { options in
            options.dsn = dsn
            options.sendDefaultPii = false
            #if DEBUG
            options.environment = "debug"
            #else
            options.environment = "production"
            #endif
        }
    }

    static func stop() {
        SentrySDK.close()
    }
}
