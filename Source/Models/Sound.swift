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

    /// Plays immediately through AppKit. Used for in-app previews when the user
    /// picks a sound. This is direct audio playback, not a notification, so it
    /// is intentionally not subject to Focus: a preview should always be audible.
    var nsSound: NSSound? {
        guard let url = bundledURL else { return nil }
        return NSSound(contentsOf: url, byReference: true)
    }

    /// The sound for a delivered notification. macOS plays it as part of
    /// delivering the notification, so it respects Focus / Do Not Disturb.
    ///
    /// On macOS `UNNotificationSound(named:)` resolves names from the user
    /// Library's `Sounds` folder (and the sandbox container's equivalent), not
    /// from the app bundle's `Resources` directory. So we stage the bundled
    /// file into `~/Library/Sounds` on first use and reference it by that name.
    /// Returns nil if the bundled file is missing or staging fails, so the
    /// caller can fall back to the default notification sound.
    func notificationSound() -> UNNotificationSound? {
        guard let stagedName = stagedSoundFileName() else { return nil }
        return UNNotificationSound(named: UNNotificationSoundName(stagedName))
    }

    /// Every sound, both the macOS classics and the custom clips, ships as
    /// `<rawValue>.aiff` at the app bundle's resource root (the system sounds are
    /// bundled as copies; everything sits at the root in one flat group).
    private var bundledURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "aiff")
    }

    /// Copies the bundled sound into `~/Library/Sounds` (only when missing or a
    /// different size) and returns the staged file name, or nil on failure. The
    /// `MailNotifier-` prefix namespaces the files so they are identifiable and
    /// don't collide with the user's existing sounds.
    private func stagedSoundFileName() -> String? {
        guard let source = bundledURL else { return nil }
        let fileName = "MailNotifier-\(rawValue).aiff"
        let fileManager = FileManager.default

        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        let soundsDirectory = library.appendingPathComponent("Sounds", isDirectory: true)
        let destination = soundsDirectory.appendingPathComponent(fileName)

        do {
            if !fileManager.fileExists(atPath: soundsDirectory.path) {
                try fileManager.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
            }
            if !stagedFileIsCurrent(source: source, destination: destination, fileManager: fileManager) {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: source, to: destination)
            }
            return fileName
        } catch {
            return nil
        }
    }

    private func stagedFileIsCurrent(source: URL, destination: URL, fileManager: FileManager) -> Bool {
        let sourceSize = (try? fileManager.attributesOfItem(atPath: source.path))?[.size] as? Int
        let destinationSize = (try? fileManager.attributesOfItem(atPath: destination.path))?[.size] as? Int
        guard let sourceSize, let destinationSize else { return false }
        return sourceSize == destinationSize
    }
}
