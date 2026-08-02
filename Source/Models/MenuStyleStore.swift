//
//  MenuStyleStore.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import Combine

// MARK: - Menu Style

/// Which dropdown the menu bar icon opens on a left click.
///
/// `pretty` is the themed SwiftUI popover. `classic` is a plain AppKit
/// `NSMenu` that follows the system light/dark appearance and ignores the
/// theme picker entirely.
enum MenuStyle: String, CaseIterable, Identifiable {
    case pretty
    case classic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pretty:  return NSLocalizedString("Pretty", comment: "Menu style: themed popover")
        case .classic: return NSLocalizedString("Classic", comment: "Menu style: standard macOS menu")
        }
    }

    var summary: String {
        switch self {
        case .pretty:
            return NSLocalizedString("Themed popover with message previews.", comment: "")
        case .classic:
            return NSLocalizedString("Standard macOS menu that follows the system appearance.", comment: "")
        }
    }
}

// MARK: - Store

final class MenuStyleStore: ObservableObject {
    static let shared = MenuStyleStore()

    static let defaultsKey = "settings.menuStyle"

    @Published var current: MenuStyle {
        didSet {
            guard oldValue != current else { return }
            UserDefaults.standard.set(current.rawValue, forKey: Self.defaultsKey)
            // `from`/`to` on the event answers "which way are switches going",
            // the person property answers "where did everyone end up".
            Telemetry.capture(
                .menuStyleChanged,
                // `style` is what 3.5.0 shipped and what the dashboard breaks
                // down on; keep sending it so the series doesn't split in two
                // when this build lands. `from`/`to` are the new detail.
                properties: [
                    "style": current.rawValue,
                    "from": oldValue.rawValue,
                    "to": current.rawValue
                ],
                userProperties: ["menu_style": current.rawValue]
            )
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? MenuStyle.pretty.rawValue
        self.current = MenuStyle(rawValue: raw) ?? .pretty
    }
}
