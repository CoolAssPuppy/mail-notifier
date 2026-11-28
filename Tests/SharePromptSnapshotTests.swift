//
//  SharePromptSnapshotTests.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit
import SwiftUI
import XCTest
@testable import Mail_Notifier

/// Renders the share prompt in its real views to PNG files for review.
///
/// Runs only when `SNAPSHOT_DIR` is set, for example:
/// `TEST_RUNNER_SNAPSHOT_DIR=/tmp/shots xcodebuild test -only-testing:MailNotifierTests/SharePromptSnapshotTests`.
/// The views use demo accounts in a throwaway defaults suite, never the
/// person's own.
@MainActor
final class SharePromptSnapshotTests: XCTestCase {
    private var outputDirectory: URL!
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        guard let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !path.isEmpty else {
            throw XCTSkip("Set SNAPSHOT_DIR to render share prompt screenshots")
        }
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        suiteName = "SharePromptSnapshotTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        Accounts.defaults = defaults
        var work = Account(email: "maya@northwind.studio", type: .outlook)
        work.tenantID = "3f2c1a7e-0000-4000-8000-000000000001"
        Accounts.default = [Account(email: "maya.chen@gmail.com", type: .gmail), work]
    }

    override func tearDown() {
        if let suiteName { defaults?.removePersistentDomain(forName: suiteName) }
        Accounts.defaults = .standard
        super.tearDown()
    }

    func testRenderSharePromoInBothPlacements() throws {
        let theme = ThemeStore.shared.palette
        let model = MenuBarPopoverModel()
        model.advancePromoForOpening()

        try render(MenuBarPopover(model: model, actions: .preview), named: "1-popover-share")
        try render(
            Sidebar(selection: .constant("maya.chen@gmail.com"), totalUnread: 3)
                .frame(width: 260, height: 520)
                .defaultAppStorage(defaults)
                .environment(\.theme, theme),
            named: "2-sidebar-share"
        )

        let light = ThemePalette.systemLight
        try render(
            Sidebar(selection: .constant("maya.chen@gmail.com"), totalUnread: 3)
                .frame(width: 260, height: 520)
                .defaultAppStorage(defaults)
                .environment(\.theme, light),
            named: "3-light-sidebar-share", appearance: light.nsAppearance
        )
    }

    private func render<V: View>(_ view: V, named name: String, settle: TimeInterval = 0.3,
                                 appearance: NSAppearance? = ThemeStore.shared.palette.nsAppearance) throws {
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = appearance
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(settle))
        host.layoutSubtreeIfNeeded()

        let scale: CGFloat = 2
        let size = host.bounds.size
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            throw XCTSkip("Could not allocate a bitmap")
        }
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try data.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }
}

private extension MenuBarPopoverActions {
    static let preview = MenuBarPopoverActions(
        openMessage: { _ in }, openInbox: { _ in }, reauthorize: { _ in }, checkAll: {},
        openWindow: {}, openSettings: {}, subscribe: {}, openNotificationSettings: {}, quit: {}
    )
}
