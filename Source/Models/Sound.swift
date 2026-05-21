//
//  Sound.swift
//  Mail Notifier
//

//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import AppKit
import UserNotifications

enum Sound: String, Identifiable, CaseIterable {
    // System sounds (alphabetized)
    case basso
    case blow
    case bottle
    case frog
    case funk
    case glass
    case hero
    case morse
    case ping
    case pop
    case purr
    case sosumi
    case submarine
    case tink

    // Custom sounds (alphabetized)
    case blink
    case chimes
    case iLoveYou = "i-love-you"
    case megRyan = "meg-ryan"
    case minstrel
    case ominous
    case organ
    case pong
    case power
    case ramius
    case robot
    case splat
    case spring
    case vader
    case wacky
    case wahWah = "wah-wah"
    case whimsy
    case whistle

    var id: String {
        rawValue
    }
}

extension Sound {
    var name: String {
        // Convert raw value to display name
        // "meg-ryan" -> "Meg Ryan", "robot" -> "Robot"
        rawValue
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    /// Every sound, both the macOS classics and the custom clips, ships as
    /// `<rawValue>.aiff` at the app bundle's resource root. The macOS system
    /// sounds are bundled as copies because `UNNotificationSound` cannot reach
    /// `/System/Library/Sounds`, and all files live at the root because
    /// `UNNotificationSound(named:)` does not recurse into bundle subfolders.
    private var fileName: String {
        "\(rawValue).aiff"
    }

    /// Plays immediately through AppKit. Used for in-app previews when the user
    /// picks a sound. This is direct audio playback, not a notification, so it
    /// is intentionally not subject to Focus: a preview should always be audible.
    var nsSound: NSSound? {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "aiff") else {
            return nil
        }
        return NSSound(contentsOf: url, byReference: true)
    }

    /// The sound handed to a delivered notification. macOS plays it as part of
    /// delivering the notification, so it correctly respects Focus / Do Not
    /// Disturb, unlike `nsSound` playback.
    var notificationSound: UNNotificationSound {
        UNNotificationSound(named: UNNotificationSoundName(fileName))
    }
}
