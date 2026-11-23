//
//  WakeCheckThrottle.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import Foundation

/// Waking the Mac and unlocking the screen usually arrive seconds apart. One
/// check covers both.
struct WakeCheckThrottle {
    var minimumGap: TimeInterval = 60
    private var lastCheck: Date?

    mutating func shouldCheck(at date: Date) -> Bool {
        if let lastCheck, date.timeIntervalSince(lastCheck) < minimumGap { return false }
        lastCheck = date
        return true
    }
}
