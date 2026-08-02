//
//  ClassicMenuFooterView.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import AppKit

// MARK: - Footer

/// The thin icon strip at the bottom of the classic menu: check all, main
/// window and settings on the left, quit on the right.
///
/// Deliberately AppKit rather than an `NSHostingView`. A menu item's custom
/// view inherits the menu's effective appearance for free here, which is
/// exactly the "inherit system light/dark" behavior classic mode promises,
/// and plain `NSButton`s track clicks inside a live menu more reliably than
/// SwiftUI buttons do.
final class ClassicMenuFooterView: NSView {
    struct Actions {
        var checkAll: () -> Void
        var openWindow: () -> Void
        var openSettings: () -> Void
        var quit: () -> Void
    }

    private static let buttonSize = NSSize(width: 26, height: 22)
    private static let horizontalInset: CGFloat = 12
    private static let spacing: CGFloat = 2
    private static let height: CGFloat = 30

    private let actions: Actions
    private var leadingButtons: [NSButton] = []
    private var trailingButton: NSButton?

    init(actions: Actions) {
        self.actions = actions
        // The width is a starting point only. Menus stretch a custom view to
        // the widest item, and `.width` in the autoresizing mask lets that
        // happen; `layout()` re-pins the quit button to the new trailing edge.
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: Self.height))
        autoresizingMask = [.width]
        buildButtons()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildButtons() {
        leadingButtons = [
            makeButton(symbol: "arrow.triangle.2.circlepath",
                       help: NSLocalizedString("Check all accounts now", comment: ""),
                       action: #selector(checkAllTapped)),
            makeButton(symbol: "macwindow",
                       help: NSLocalizedString("Open main window", comment: ""),
                       action: #selector(openWindowTapped)),
            makeButton(symbol: "gearshape",
                       help: NSLocalizedString("Settings", comment: ""),
                       action: #selector(openSettingsTapped))
        ]

        let quit = makeButton(symbol: "power",
                              help: NSLocalizedString("Quit Mail Notifier", comment: ""),
                              action: #selector(quitTapped))
        trailingButton = quit

        (leadingButtons + [quit]).forEach(addSubview)
        needsLayout = true
    }

    private func makeButton(symbol: String, help: String, action: Selector) -> NSButton {
        let button = ClassicFooterButton(image: symbolImage(named: symbol), target: self, action: action)
        button.toolTip = help
        button.setAccessibilityLabel(help)
        button.setFrameSize(Self.buttonSize)
        return button
    }

    private func symbolImage(named symbol: String) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image ?? NSImage()
    }

    override func layout() {
        super.layout()

        let verticalOrigin = (bounds.height - Self.buttonSize.height) / 2
        var x = Self.horizontalInset

        for button in leadingButtons {
            button.setFrameOrigin(NSPoint(x: x, y: verticalOrigin))
            x += Self.buttonSize.width + Self.spacing
        }

        trailingButton?.setFrameOrigin(
            NSPoint(x: bounds.width - Self.horizontalInset - Self.buttonSize.width, y: verticalOrigin)
        )
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.height)
    }

    /// Menus stay open until told otherwise, so every action closes the menu
    /// first and then runs — matching what a normal menu item does.
    private func dismissMenu() {
        enclosingMenuItem?.menu?.cancelTracking()
    }

    @objc private func checkAllTapped() {
        dismissMenu()
        actions.checkAll()
    }

    @objc private func openWindowTapped() {
        dismissMenu()
        actions.openWindow()
    }

    @objc private func openSettingsTapped() {
        dismissMenu()
        actions.openSettings()
    }

    @objc private func quitTapped() {
        dismissMenu()
        actions.quit()
    }
}

// MARK: - Footer Button

/// Borderless icon button with the rounded hover wash macOS uses for inline
/// menu controls.
private final class ClassicFooterButton: NSButton {
    private var trackingArea: NSTrackingArea?

    init(image: NSImage, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        self.image = image
        self.target = target
        self.action = action
        title = ""
        imagePosition = .imageOnly
        isBordered = false
        bezelStyle = .shadowlessSquare
        contentTintColor = .secondaryLabelColor
        wantsLayer = true
        layer?.cornerRadius = 5
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeInActiveApp],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        contentTintColor = .labelColor
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        contentTintColor = .secondaryLabelColor
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}
