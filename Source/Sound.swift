//
//  Sound.swift
//  Mail Notifier
//
//  Created by James Chen on 2021/06/19.
//  Copyright © 2021 ashchan.com. All rights reserved.
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

    private var isCustomSound: Bool {
        switch self {
        case .blink, .chimes, .iLoveYou, .megRyan, .minstrel, .ominous, .organ,
             .pong, .power, .ramius, .robot, .splat, .spring, .vader, .wacky,
             .wahWah, .whimsy, .whistle:
            return true
        default:
            return false
        }
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
