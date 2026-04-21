//
//  ThemeStore.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Palette

struct ThemePalette: Equatable {
    let isDark: Bool

    // Surfaces
    let background: Color
    let surface: Color
    let card: Color
    let cardElevated: Color
    let cardInset: Color

    // Borders
    let border: Color
    let borderStrong: Color
    let borderFocus: Color
    let divider: Color
    let dividerSubtle: Color

    // Text
    let foreground: Color
    let foregroundSoft: Color
    let muted: Color
    let tertiary: Color
    let dim: Color

    // Semantic
    let primary: Color
    let primaryDeep: Color
    let primaryForeground: Color
    let success: Color
    let warning: Color
    let destructive: Color

    // AppKit-bridged values for the window chrome.
    var nsBackground: NSColor { NSColor(background) }
    var nsAppearance: NSAppearance? { NSAppearance(named: isDark ? .darkAqua : .aqua) }
}

// MARK: - Themes

enum AppTheme: String, CaseIterable, Identifiable {
    case system

    // Light
    case hoth
    case risa
    case weasley
    case starbuck

    // Dark
    case cylon
    case vader
    case kirk
    case hermione
    case nerds

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:   return "System"
        case .hoth:     return "Hoth"
        case .risa:     return "Risa"
        case .weasley:  return "Weasley"
        case .starbuck: return "Starbuck"
        case .cylon:    return "Cylon"
        case .vader:    return "Vader"
        case .kirk:     return "Kirk"
        case .hermione: return "Hermione"
        case .nerds:    return "Nerds"
        }
    }

    var isDark: Bool { palette.isDark }

    var palette: ThemePalette {
        switch self {
        case .system:
            let isDark = (NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua) == .darkAqua
            return isDark ? .systemDark : .systemLight
        case .hoth:     return .hoth
        case .risa:     return .risa
        case .weasley:  return .weasley
        case .starbuck: return .starbuck
        case .cylon:    return .cylon
        case .vader:    return .vader
        case .kirk:     return .kirk
        case .hermione: return .hermione
        case .nerds:    return .nerds
        }
    }
}

// MARK: - Palette definitions

extension ThemePalette {
    // MARK: System

    /// Neutral light palette used when the user picks "System" and macOS is
    /// in light mode. Leans on system blue for primary so it feels native.
    static let systemLight = ThemePalette(
        isDark: false,
        background:     Color(red: 0xF5/255, green: 0xF5/255, blue: 0xF7/255),
        surface:        Color(red: 0xEC/255, green: 0xEC/255, blue: 0xEF/255),
        card:           Color(red: 0xFF/255, green: 0xFF/255, blue: 0xFF/255),
        cardElevated:   Color(red: 0xF4/255, green: 0xF4/255, blue: 0xF7/255),
        cardInset:      Color(red: 0xF0/255, green: 0xF0/255, blue: 0xF3/255),
        border:         Color(red: 0xDC/255, green: 0xDC/255, blue: 0xE0/255),
        borderStrong:   Color(red: 0xC3/255, green: 0xC3/255, blue: 0xC8/255),
        borderFocus:    Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255).opacity(0.45),
        divider:        Color(red: 0xE3/255, green: 0xE3/255, blue: 0xE7/255),
        dividerSubtle:  Color(red: 0xEE/255, green: 0xEE/255, blue: 0xF1/255),
        foreground:     Color(red: 0x0F/255, green: 0x0F/255, blue: 0x14/255),
        foregroundSoft: Color(red: 0x27/255, green: 0x27/255, blue: 0x30/255),
        muted:          Color(red: 0x55/255, green: 0x55/255, blue: 0x5F/255),
        tertiary:       Color(red: 0x78/255, green: 0x78/255, blue: 0x82/255),
        dim:            Color(red: 0xB3/255, green: 0xB3/255, blue: 0xBA/255),
        primary:        Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255),
        primaryDeep:    Color(red: 0x00/255, green: 0x55/255, blue: 0xCC/255),
        primaryForeground: .white,
        success:        Color(red: 0x1E/255, green: 0x82/255, blue: 0x44/255),
        warning:        Color(red: 0xB4/255, green: 0x5F/255, blue: 0x06/255),
        destructive:    Color(red: 0xC5/255, green: 0x1F/255, blue: 0x2E/255)
    )

    /// System dark — used when the user picks "System" and macOS is in dark
    /// mode. A restrained neutral dark palette that matches Apple's own apps.
    static let systemDark = ThemePalette(
        isDark: true,
        background:     Color(red: 0x1E/255, green: 0x1E/255, blue: 0x1E/255),
        surface:        Color(red: 0x26/255, green: 0x26/255, blue: 0x26/255),
        card:           Color(red: 0x2D/255, green: 0x2D/255, blue: 0x2D/255),
        cardElevated:   Color(red: 0x36/255, green: 0x36/255, blue: 0x36/255),
        cardInset:      Color(red: 0x21/255, green: 0x21/255, blue: 0x21/255),
        border:         Color(red: 0x3A/255, green: 0x3A/255, blue: 0x3A/255),
        borderStrong:   Color(red: 0x4A/255, green: 0x4A/255, blue: 0x4A/255),
        borderFocus:    Color(red: 0x0A/255, green: 0x84/255, blue: 0xFF/255).opacity(0.5),
        divider:        Color(red: 0x30/255, green: 0x30/255, blue: 0x30/255),
        dividerSubtle:  Color(red: 0x28/255, green: 0x28/255, blue: 0x28/255),
        foreground:     Color(red: 0xF5/255, green: 0xF5/255, blue: 0xF5/255),
        foregroundSoft: Color(red: 0xD7/255, green: 0xD7/255, blue: 0xD7/255),
        muted:          Color(red: 0xA3/255, green: 0xA3/255, blue: 0xA3/255),
        tertiary:       Color(red: 0x7A/255, green: 0x7A/255, blue: 0x7A/255),
        dim:            Color(red: 0x55/255, green: 0x55/255, blue: 0x55/255),
        primary:        Color(red: 0x0A/255, green: 0x84/255, blue: 0xFF/255),
        primaryDeep:    Color(red: 0x00/255, green: 0x66/255, blue: 0xCC/255),
        primaryForeground: .white,
        success:        Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255),
        warning:        Color(red: 0xFB/255, green: 0xBF/255, blue: 0x24/255),
        destructive:    Color(red: 0xF8/255, green: 0x71/255, blue: 0x71/255)
    )

    // MARK: Light

    /// Hoth — ice planet, Star Wars. Cool whites and glacier blue.
    static let hoth = ThemePalette(
        isDark: false,
        background:     Color(red: 0xF4/255, green: 0xF8/255, blue: 0xFC/255),
        surface:        Color(red: 0xEA/255, green: 0xF1/255, blue: 0xF8/255),
        card:           Color(red: 0xFF/255, green: 0xFF/255, blue: 0xFF/255),
        cardElevated:   Color(red: 0xF4/255, green: 0xF8/255, blue: 0xFC/255),
        cardInset:      Color(red: 0xED/255, green: 0xF4/255, blue: 0xFA/255),
        border:         Color(red: 0xD8/255, green: 0xE4/255, blue: 0xF1/255),
        borderStrong:   Color(red: 0xC2/255, green: 0xD2/255, blue: 0xE5/255),
        borderFocus:    Color(red: 0x31/255, green: 0x82/255, blue: 0xCE/255).opacity(0.45),
        divider:        Color(red: 0xDF/255, green: 0xEA/255, blue: 0xF4/255),
        dividerSubtle:  Color(red: 0xEC/255, green: 0xF3/255, blue: 0xF9/255),
        foreground:     Color(red: 0x1A/255, green: 0x20/255, blue: 0x2C/255),
        foregroundSoft: Color(red: 0x2D/255, green: 0x3B/255, blue: 0x4F/255),
        muted:          Color(red: 0x4A/255, green: 0x5B/255, blue: 0x72/255),
        tertiary:       Color(red: 0x70/255, green: 0x83/255, blue: 0x9B/255),
        dim:            Color(red: 0xB3/255, green: 0xC3/255, blue: 0xD6/255),
        primary:        Color(red: 0x31/255, green: 0x82/255, blue: 0xCE/255),
        primaryDeep:    Color(red: 0x2C/255, green: 0x52/255, blue: 0x82/255),
        primaryForeground: .white,
        success:        Color(red: 0x15/255, green: 0x80/255, blue: 0x3D/255),
        warning:        Color(red: 0xC0/255, green: 0x5A/255, blue: 0x17/255),
        destructive:    Color(red: 0xC5/255, green: 0x1F/255, blue: 0x2E/255)
    )

    /// Risa — pleasure planet, Star Trek. Warm pinks and coral.
    static let risa = ThemePalette(
        isDark: false,
        background:     Color(red: 0xFF/255, green: 0xF5/255, blue: 0xF7/255),
        surface:        Color(red: 0xFE/255, green: 0xE7/255, blue: 0xEE/255),
        card:           Color(red: 0xFF/255, green: 0xFF/255, blue: 0xFF/255),
        cardElevated:   Color(red: 0xFF/255, green: 0xED/255, blue: 0xF3/255),
        cardInset:      Color(red: 0xFE/255, green: 0xE1/255, blue: 0xEB/255),
        border:         Color(red: 0xFA/255, green: 0xC4/255, blue: 0xD4/255),
        borderStrong:   Color(red: 0xF0/255, green: 0xA7/255, blue: 0xBD/255),
        borderFocus:    Color(red: 0xE5/255, green: 0x3E/255, blue: 0x82/255).opacity(0.45),
        divider:        Color(red: 0xFC/255, green: 0xCE/255, blue: 0xDB/255),
        dividerSubtle:  Color(red: 0xFE/255, green: 0xDE/255, blue: 0xE8/255),
        foreground:     Color(red: 0x2D/255, green: 0x1B/255, blue: 0x25/255),
        foregroundSoft: Color(red: 0x4F/255, green: 0x2C/255, blue: 0x3F/255),
        muted:          Color(red: 0x78/255, green: 0x47/255, blue: 0x5B/255),
        tertiary:       Color(red: 0xA0/255, green: 0x6B/255, blue: 0x82/255),
        dim:            Color(red: 0xD8/255, green: 0xAF/255, blue: 0xBF/255),
        primary:        Color(red: 0xE5/255, green: 0x3E/255, blue: 0x82/255),
        primaryDeep:    Color(red: 0xB8/255, green: 0x32/255, blue: 0x80/255),
        primaryForeground: .white,
        success:        Color(red: 0x2F/255, green: 0x85/255, blue: 0x5F/255),
        warning:        Color(red: 0xC2/255, green: 0x6A/255, blue: 0x1E/255),
        destructive:    Color(red: 0xB8/255, green: 0x25/255, blue: 0x3F/255)
    )

    /// Weasley — Harry Potter. Burnt orange and cream.
    static let weasley = ThemePalette(
        isDark: false,
        background:     Color(red: 0xFF/255, green: 0xF7/255, blue: 0xED/255),
        surface:        Color(red: 0xFF/255, green: 0xEC/255, blue: 0xD6/255),
        card:           Color(red: 0xFF/255, green: 0xFF/255, blue: 0xFD/255),
        cardElevated:   Color(red: 0xFF/255, green: 0xF1/255, blue: 0xDD/255),
        cardInset:      Color(red: 0xFE/255, green: 0xE6/255, blue: 0xCA/255),
        border:         Color(red: 0xFB/255, green: 0xC6/255, blue: 0x95/255),
        borderStrong:   Color(red: 0xEA/255, green: 0xA9/255, blue: 0x6B/255),
        borderFocus:    Color(red: 0xEA/255, green: 0x58/255, blue: 0x0C/255).opacity(0.45),
        divider:        Color(red: 0xFD/255, green: 0xD5/255, blue: 0xAA/255),
        dividerSubtle:  Color(red: 0xFF/255, green: 0xE3/255, blue: 0xC3/255),
        foreground:     Color(red: 0x1C/255, green: 0x19/255, blue: 0x17/255),
        foregroundSoft: Color(red: 0x44/255, green: 0x2B/255, blue: 0x18/255),
        muted:          Color(red: 0x6B/255, green: 0x49/255, blue: 0x2C/255),
        tertiary:       Color(red: 0x96/255, green: 0x6C/255, blue: 0x43/255),
        dim:            Color(red: 0xCF/255, green: 0xA6/255, blue: 0x78/255),
        primary:        Color(red: 0xEA/255, green: 0x58/255, blue: 0x0C/255),
        primaryDeep:    Color(red: 0xC2/255, green: 0x41/255, blue: 0x0C/255),
        primaryForeground: .white,
        success:        Color(red: 0x3F/255, green: 0x6F/255, blue: 0x1D/255),
        warning:        Color(red: 0xB4/255, green: 0x5F/255, blue: 0x13/255),
        destructive:    Color(red: 0xB8/255, green: 0x2D/255, blue: 0x1E/255)
    )

    /// Starbuck — BSG Viper pilot. Sand and coffee.
    static let starbuck = ThemePalette(
        isDark: false,
        background:     Color(red: 0xF5/255, green: 0xF2/255, blue: 0xEA/255),
        surface:        Color(red: 0xEA/255, green: 0xE4/255, blue: 0xD2/255),
        card:           Color(red: 0xFE/255, green: 0xFC/255, blue: 0xF6/255),
        cardElevated:   Color(red: 0xF1/255, green: 0xEC/255, blue: 0xDB/255),
        cardInset:      Color(red: 0xE6/255, green: 0xDF/255, blue: 0xC8/255),
        border:         Color(red: 0xC8/255, green: 0xBD/255, blue: 0x9C/255),
        borderStrong:   Color(red: 0xAE/255, green: 0xA1/255, blue: 0x79/255),
        borderFocus:    Color(red: 0x8B/255, green: 0x6F/255, blue: 0x47/255).opacity(0.45),
        divider:        Color(red: 0xD4/255, green: 0xCB/255, blue: 0xAA/255),
        dividerSubtle:  Color(red: 0xDF/255, green: 0xD7/255, blue: 0xBA/255),
        foreground:     Color(red: 0x26/255, green: 0x1E/255, blue: 0x10/255),
        foregroundSoft: Color(red: 0x44/255, green: 0x36/255, blue: 0x1E/255),
        muted:          Color(red: 0x6B/255, green: 0x57/255, blue: 0x33/255),
        tertiary:       Color(red: 0x8A/255, green: 0x76/255, blue: 0x51/255),
        dim:            Color(red: 0xBA/255, green: 0xAB/255, blue: 0x80/255),
        primary:        Color(red: 0x8B/255, green: 0x6F/255, blue: 0x47/255),
        primaryDeep:    Color(red: 0x5C/255, green: 0x46/255, blue: 0x28/255),
        primaryForeground: .white,
        success:        Color(red: 0x4F/255, green: 0x6C/255, blue: 0x24/255),
        warning:        Color(red: 0xA8/255, green: 0x58/255, blue: 0x16/255),
        destructive:    Color(red: 0xA3/255, green: 0x2C/255, blue: 0x22/255)
    )

    // MARK: Dark

    /// Cylon — BSG. Scan-line red on black.
    static let cylon = ThemePalette(
        isDark: true,
        background:     Color(red: 0x0A/255, green: 0x0A/255, blue: 0x0A/255),
        surface:        Color(red: 0x13/255, green: 0x13/255, blue: 0x13/255),
        card:           Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1C/255),
        cardElevated:   Color(red: 0x26/255, green: 0x26/255, blue: 0x26/255),
        cardInset:      Color(red: 0x11/255, green: 0x11/255, blue: 0x11/255),
        border:         Color(red: 0x2B/255, green: 0x2B/255, blue: 0x2B/255),
        borderStrong:   Color(red: 0x3A/255, green: 0x3A/255, blue: 0x3A/255),
        borderFocus:    Color(red: 0xEF/255, green: 0x44/255, blue: 0x44/255).opacity(0.45),
        divider:        Color(red: 0x22/255, green: 0x22/255, blue: 0x22/255),
        dividerSubtle:  Color(red: 0x1B/255, green: 0x1B/255, blue: 0x1B/255),
        foreground:     Color(red: 0xF5/255, green: 0xF5/255, blue: 0xF5/255),
        foregroundSoft: Color(red: 0xD4/255, green: 0xD4/255, blue: 0xD4/255),
        muted:          Color(red: 0xA1/255, green: 0xA1/255, blue: 0xA1/255),
        tertiary:       Color(red: 0x78/255, green: 0x78/255, blue: 0x78/255),
        dim:            Color(red: 0x52/255, green: 0x52/255, blue: 0x52/255),
        primary:        Color(red: 0xEF/255, green: 0x44/255, blue: 0x44/255),
        primaryDeep:    Color(red: 0x99/255, green: 0x1B/255, blue: 0x1B/255),
        primaryForeground: .white,
        success:        Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255),
        warning:        Color(red: 0xFB/255, green: 0xBF/255, blue: 0x24/255),
        destructive:    Color(red: 0xF8/255, green: 0x71/255, blue: 0x71/255)
    )

    /// Vader — Sith. Deep black with sith crimson.
    static let vader = ThemePalette(
        isDark: true,
        background:     Color(red: 0x0C/255, green: 0x0A/255, blue: 0x0E/255),
        surface:        Color(red: 0x14/255, green: 0x11/255, blue: 0x18/255),
        card:           Color(red: 0x1D/255, green: 0x19/255, blue: 0x22/255),
        cardElevated:   Color(red: 0x29/255, green: 0x22/255, blue: 0x30/255),
        cardInset:      Color(red: 0x14/255, green: 0x11/255, blue: 0x18/255),
        border:         Color(red: 0x33/255, green: 0x2A/255, blue: 0x3A/255),
        borderStrong:   Color(red: 0x45/255, green: 0x39/255, blue: 0x4D/255),
        borderFocus:    Color(red: 0xDC/255, green: 0x26/255, blue: 0x26/255).opacity(0.45),
        divider:        Color(red: 0x27/255, green: 0x1F/255, blue: 0x2D/255),
        dividerSubtle:  Color(red: 0x1E/255, green: 0x1A/255, blue: 0x23/255),
        foreground:     Color(red: 0xF5/255, green: 0xF3/255, blue: 0xF7/255),
        foregroundSoft: Color(red: 0xD7/255, green: 0xD3/255, blue: 0xDC/255),
        muted:          Color(red: 0x9A/255, green: 0x91/255, blue: 0xA4/255),
        tertiary:       Color(red: 0x73/255, green: 0x68/255, blue: 0x7D/255),
        dim:            Color(red: 0x4E/255, green: 0x44/255, blue: 0x56/255),
        primary:        Color(red: 0xDC/255, green: 0x26/255, blue: 0x26/255),
        primaryDeep:    Color(red: 0x7F/255, green: 0x1D/255, blue: 0x1D/255),
        primaryForeground: .white,
        success:        Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255),
        warning:        Color(red: 0xFB/255, green: 0xBF/255, blue: 0x24/255),
        destructive:    Color(red: 0xFF/255, green: 0x6B/255, blue: 0x6B/255)
    )

    /// Kirk — Star Trek TOS command gold on navy.
    static let kirk = ThemePalette(
        isDark: true,
        background:     Color(red: 0x0A/255, green: 0x16/255, blue: 0x27/255),
        surface:        Color(red: 0x0E/255, green: 0x1E/255, blue: 0x36/255),
        card:           Color(red: 0x14/255, green: 0x25/255, blue: 0x3F/255),
        cardElevated:   Color(red: 0x1C/255, green: 0x30/255, blue: 0x52/255),
        cardInset:      Color(red: 0x0B/255, green: 0x1B/255, blue: 0x30/255),
        border:         Color(red: 0x1E/255, green: 0x3A/255, blue: 0x5F/255),
        borderStrong:   Color(red: 0x2B/255, green: 0x4D/255, blue: 0x7A/255),
        borderFocus:    Color(red: 0xEA/255, green: 0xB3/255, blue: 0x08/255).opacity(0.5),
        divider:        Color(red: 0x15/255, green: 0x2B/255, blue: 0x48/255),
        dividerSubtle:  Color(red: 0x10/255, green: 0x22/255, blue: 0x3B/255),
        foreground:     Color(red: 0xF1/255, green: 0xF5/255, blue: 0xF9/255),
        foregroundSoft: Color(red: 0xCB/255, green: 0xD5/255, blue: 0xE1/255),
        muted:          Color(red: 0x94/255, green: 0xA3/255, blue: 0xB8/255),
        tertiary:       Color(red: 0x64/255, green: 0x74/255, blue: 0x8B/255),
        dim:            Color(red: 0x44/255, green: 0x50/255, blue: 0x65/255),
        primary:        Color(red: 0xEA/255, green: 0xB3/255, blue: 0x08/255),
        primaryDeep:    Color(red: 0xA1/255, green: 0x62/255, blue: 0x07/255),
        primaryForeground: Color(red: 0x0A/255, green: 0x16/255, blue: 0x27/255),
        success:        Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255),
        warning:        Color(red: 0xFB/255, green: 0xBF/255, blue: 0x24/255),
        destructive:    Color(red: 0xF8/255, green: 0x71/255, blue: 0x71/255)
    )

    /// Nerds — Strategic Nerds brand. #121212 canvas, #FCDE09 primary.
    static let nerds = ThemePalette(
        isDark: true,
        background:     Color(red: 0x12/255, green: 0x12/255, blue: 0x12/255),
        surface:        Color(red: 0x17/255, green: 0x17/255, blue: 0x17/255),
        card:           Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1C/255),
        cardElevated:   Color(red: 0x26/255, green: 0x26/255, blue: 0x26/255),
        cardInset:      Color(red: 0x0E/255, green: 0x0E/255, blue: 0x0E/255),
        border:         Color(red: 0x2A/255, green: 0x2A/255, blue: 0x2A/255),
        borderStrong:   Color(red: 0x38/255, green: 0x38/255, blue: 0x38/255),
        borderFocus:    Color(red: 0xFC/255, green: 0xDE/255, blue: 0x09/255).opacity(0.55),
        divider:        Color(red: 0x22/255, green: 0x22/255, blue: 0x22/255),
        dividerSubtle:  Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255),
        foreground:     Color(red: 0xF5/255, green: 0xF5/255, blue: 0xF5/255),
        foregroundSoft: Color(red: 0xD4/255, green: 0xD4/255, blue: 0xD4/255),
        muted:          Color(red: 0xA3/255, green: 0xA3/255, blue: 0xA3/255),
        tertiary:       Color(red: 0x73/255, green: 0x73/255, blue: 0x73/255),
        dim:            Color(red: 0x4D/255, green: 0x4D/255, blue: 0x4D/255),
        primary:        Color(red: 0xFC/255, green: 0xDE/255, blue: 0x09/255),
        primaryDeep:    Color(red: 0xD4/255, green: 0xA8/255, blue: 0x06/255),
        primaryForeground: Color(red: 0x12/255, green: 0x12/255, blue: 0x12/255),
        success:        Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255),
        warning:        Color(red: 0xFC/255, green: 0xDE/255, blue: 0x09/255),
        destructive:    Color(red: 0xF8/255, green: 0x71/255, blue: 0x71/255)
    )

    /// Hermione — deep purple / aubergine with lilac primary.
    static let hermione = ThemePalette(
        isDark: true,
        background:     Color(red: 0x14/255, green: 0x12/255, blue: 0x1F/255),
        surface:        Color(red: 0x1B/255, green: 0x17/255, blue: 0x28/255),
        card:           Color(red: 0x24/255, green: 0x1E/255, blue: 0x35/255),
        cardElevated:   Color(red: 0x2D/255, green: 0x25/255, blue: 0x42/255),
        cardInset:      Color(red: 0x19/255, green: 0x14/255, blue: 0x26/255),
        border:         Color(red: 0x34/255, green: 0x2A/255, blue: 0x4D/255),
        borderStrong:   Color(red: 0x45/255, green: 0x38/255, blue: 0x63/255),
        borderFocus:    Color(red: 0xA7/255, green: 0x8B/255, blue: 0xFA/255).opacity(0.5),
        divider:        Color(red: 0x28/255, green: 0x21/255, blue: 0x3C/255),
        dividerSubtle:  Color(red: 0x1F/255, green: 0x1A/255, blue: 0x30/255),
        foreground:     Color(red: 0xED/255, green: 0xE9/255, blue: 0xFE/255),
        foregroundSoft: Color(red: 0xCF/255, green: 0xC6/255, blue: 0xEA/255),
        muted:          Color(red: 0x9B/255, green: 0x8E/255, blue: 0xBB/255),
        tertiary:       Color(red: 0x71/255, green: 0x63/255, blue: 0x94/255),
        dim:            Color(red: 0x4C/255, green: 0x42/255, blue: 0x68/255),
        primary:        Color(red: 0xA7/255, green: 0x8B/255, blue: 0xFA/255),
        primaryDeep:    Color(red: 0x7C/255, green: 0x3A/255, blue: 0xED/255),
        primaryForeground: Color(red: 0x14/255, green: 0x12/255, blue: 0x1F/255),
        success:        Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255),
        warning:        Color(red: 0xFB/255, green: 0xBF/255, blue: 0x24/255),
        destructive:    Color(red: 0xF8/255, green: 0x71/255, blue: 0x71/255)
    )
}

// MARK: - Store

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    private static let defaultsKey = "appTheme"

    @Published var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.defaultsKey)
        }
    }

    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? AppTheme.cylon.rawValue
        self.current = AppTheme(rawValue: raw) ?? .cylon

        // When the user flips macOS between light and dark mode and the
        // System theme is active, the palette flips too — re-publish.
        appearanceObserver = NSApp?.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            guard let self, self.current == .system else { return }
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    var palette: ThemePalette { current.palette }
}

// MARK: - SwiftUI environment

private struct CurrentPaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = .cylon
}

extension EnvironmentValues {
    var theme: ThemePalette {
        get { self[CurrentPaletteKey.self] }
        set { self[CurrentPaletteKey.self] = newValue }
    }
}
