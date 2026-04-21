//
//  Theme.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

extension Color {
    // Surfaces
    static let appBackground      = Color(red: 0x0E/255, green: 0x11/255, blue: 0x17/255)
    static let appSurface         = Color(red: 0x10/255, green: 0x13/255, blue: 0x1A/255)
    static let appCard            = Color(red: 0x13/255, green: 0x17/255, blue: 0x1F/255)
    static let appCardElevated    = Color(red: 0x1A/255, green: 0x1F/255, blue: 0x29/255)
    static let appCardInset       = Color(red: 0x10/255, green: 0x13/255, blue: 0x1A/255)

    // Borders
    static let appBorder          = Color(red: 0x1F/255, green: 0x24/255, blue: 0x2E/255)
    static let appBorderStrong    = Color(red: 0x26/255, green: 0x2C/255, blue: 0x38/255)
    static let appBorderFocus     = Color(red: 0x2D/255, green: 0x39/255, blue: 0x56/255)
    static let appDivider         = Color(red: 0x1D/255, green: 0x21/255, blue: 0x29/255)
    static let appDividerSubtle   = Color(red: 0x1A/255, green: 0x1F/255, blue: 0x29/255)

    // Text
    static let appForeground      = Color(red: 0xEC/255, green: 0xEF/255, blue: 0xF4/255)
    static let appForegroundSoft  = Color(red: 0xC6/255, green: 0xCA/255, blue: 0xD3/255)
    static let appMuted           = Color(red: 0x8A/255, green: 0x8F/255, blue: 0x9A/255)
    static let appTertiary        = Color(red: 0x6B/255, green: 0x70/255, blue: 0x80/255)
    static let appDim             = Color(red: 0x3A/255, green: 0x3F/255, blue: 0x4B/255)

    // Semantic
    static let appPrimary         = Color(red: 0x4F/255, green: 0x8A/255, blue: 0xFF/255)
    static let appPrimaryDeep     = Color(red: 0x25/255, green: 0x63/255, blue: 0xEB/255)
    static let appSuccess         = Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)
    static let appWarning         = Color(red: 0xFB/255, green: 0xBF/255, blue: 0x24/255)
    static let appDestructive     = Color(red: 0xF8/255, green: 0x71/255, blue: 0x71/255)

    // Accents
    static let appAccentOrange    = Color(red: 0xFB/255, green: 0x92/255, blue: 0x3C/255)
    static let appAccentOrangeDeep = Color(red: 0xF9/255, green: 0x73/255, blue: 0x16/255)
}

enum AppRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
    static let xl: CGFloat = 12
    static let xxl: CGFloat = 14
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
    static let xxxl: CGFloat = 28
}
