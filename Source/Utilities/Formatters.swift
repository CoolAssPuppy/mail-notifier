//
//  Formatters.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

enum Formatters {
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// "January 4, 2027" for renewal and expiry dates.
    static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    /// Parses an ISO 8601 timestamp with or without fractional seconds. Polar
    /// sends fractional seconds on some fields and not others, and
    /// `ISO8601DateFormatter` returns nil rather than tolerating the mismatch.
    static func parseISO8601(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    /// The message to show a person for a thrown error. Prefers a
    /// `LocalizedError` description (ours are written for humans) and falls back
    /// to the `NSError` description (URLError's "The Internet connection appears
    /// to be offline." and friends).
    static func userMessage(for error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return localized
        }
        return (error as NSError).localizedDescription
    }

    /// Relative label for message/timestamp rows: "3:42 PM" today, "Yesterday",
    /// "Mon" within the last week, "Jan 4" older.
    static func relativeLabel(for date: Date, reference: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return shortTime.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        if let days = calendar.dateComponents([.day], from: date, to: reference).day, days < 7 {
            return weekday.string(from: date)
        }
        return shortDate.string(from: date)
    }
}
