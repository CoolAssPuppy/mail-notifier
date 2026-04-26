//
//  Sound.swift
//  Mail Notifier
//

//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import AppKit

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

    /// True when the sound is shipped as an AIFF in `Resources/Sounds/`.
    /// Derived from the actual bundle so adding a new custom sound is a
    /// one-edit change (drop the file, add the case) instead of also
    /// having to update a hand-maintained switch.
    private var isCustomSound: Bool {
        Bundle.main.url(forResource: rawValue, withExtension: "aiff", subdirectory: "Sounds") != nil
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

    var soundName: NSSound.Name {
        NSSound.Name(rawValue.capitalized)
    }

    var nsSound: NSSound? {
        if isCustomSound {
            // Load from app bundle
            if let url = Bundle.main.url(forResource: rawValue, withExtension: "aiff", subdirectory: "Sounds") {
                return NSSound(contentsOf: url, byReference: true)
            }
            return nil
        } else {
            // System sound
            return NSSound(named: soundName)
        }
    }
}
