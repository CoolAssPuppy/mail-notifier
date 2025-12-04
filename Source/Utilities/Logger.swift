//
//  Logger.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import os.log

/// Centralized logging for the app using Apple's unified logging system.
/// Use these loggers instead of print() or NSLog() for proper log management.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.strategicnerds.MailNotifierApp"

    /// General app lifecycle and UI events
    static let app = Logger(subsystem: subsystem, category: "app")

    /// OAuth authentication flow
    static let auth = Logger(subsystem: subsystem, category: "auth")

    /// Email fetching and message handling
    static let mail = Logger(subsystem: subsystem, category: "mail")

    /// Keychain and credential storage
    static let keychain = Logger(subsystem: subsystem, category: "keychain")

    /// Network requests and responses
    static let network = Logger(subsystem: subsystem, category: "network")
}
