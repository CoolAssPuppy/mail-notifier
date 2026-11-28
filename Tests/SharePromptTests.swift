//
//  SharePromptTests.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit
import SwiftUI
import XCTest
@testable import Mail_Notifier

final class SharePromptTests: XCTestCase {
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("SharePromptTests.\(UUID().uuidString)"))
    }

    func testCopyPutsOnlyTheAppPageOnThePasteboard() {
        for source in [ShareSource.menu, .settings] {
            let pasteboard = makePasteboard()
            SharePromptStore().copyLink(from: source, to: pasteboard)
            XCTAssertEqual(pasteboard.string(forType: .string), "https://www.strategicnerds.com/apps/mailnotifier")
        }
    }

    @MainActor
    func testOnlyDismissalForInstalledVersionHidesBothPlacements() throws {
        let version = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let suite = "PromoDismissalTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        for source in [ShareSource.menu, .settings] {
            let cases: [(String?, Bool)] = [(nil, true), (version, false), ("0.0.1", true)]
            for (dismissedVersion, isVisible) in cases {
                defaults.set(dismissedVersion, forKey: PromoRow.dismissedVersionKey)
                let host = NSHostingView(rootView: PromoRow(source: source).defaultAppStorage(defaults))
                XCTAssertEqual(host.fittingSize.height > 0, isVisible, "\(source), dismissed version: \(dismissedVersion ?? "none")")
            }
        }
    }
}
