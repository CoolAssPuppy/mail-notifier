//
//  SoundTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class SoundTests: XCTestCase {

    func testRawValueRoundTrip() {
        for sound in Sound.allCases {
            let restored = Sound(rawValue: sound.rawValue)
            XCTAssertEqual(restored, sound, "Sound \(sound) must roundtrip via rawValue")
        }
    }

    func testIdEqualsRawValue() {
        XCTAssertEqual(Sound.basso.id, "basso")
        XCTAssertEqual(Sound.iLoveYou.id, "i-love-you")
    }

    func testNameTitleCasesSingleWord() {
        XCTAssertEqual(Sound.robot.name, "Robot")
    }

    func testNameSplitsOnHyphenAndTitleCases() {
        XCTAssertEqual(Sound.iLoveYou.name, "I Love You")
        XCTAssertEqual(Sound.megRyan.name, "Meg Ryan")
        XCTAssertEqual(Sound.wahWah.name, "Wah Wah")
    }

    func testAllCasesIncludesBothFamilies() {
        // System sounds
        XCTAssertTrue(Sound.allCases.contains(.basso))
        XCTAssertTrue(Sound.allCases.contains(.tink))
        // Custom sounds
        XCTAssertTrue(Sound.allCases.contains(.vader))
        XCTAssertTrue(Sound.allCases.contains(.minstrel))
    }

    func testAllCasesIsExhaustive() {
        // Snapshot count guards against accidental case removal.
        XCTAssertEqual(Sound.allCases.count, 32)
    }

    func testEverySoundShipsBundledFileAtResourceRoot() {
        // The notification sound is staged into ~/Library/Sounds from the bundled
        // copy at delivery time. This asserts every sound ships as `<rawValue>.aiff`
        // at the bundle resource root so there is always a source to stage from;
        // a missing file would make the notification fall back to the default.
        for sound in Sound.allCases {
            XCTAssertNotNil(
                Bundle.main.url(forResource: sound.rawValue, withExtension: "aiff"),
                "\(sound.rawValue).aiff must ship at the bundle resource root for UNNotificationSound to find it"
            )
        }
    }

    func testPreviewSoundLoadsForEverySound() {
        // The in-app preview path must resolve a playable NSSound for each case.
        for sound in Sound.allCases {
            XCTAssertNotNil(sound.nsSound, "\(sound.rawValue) must resolve a preview NSSound")
        }
    }
}
