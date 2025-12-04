//
//  LaunchAtLoginManager.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import ServiceManagement
import SwiftUI

/// Native launch at login manager using SMAppService (macOS 13+)
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool {
        didSet {
            if isEnabled {
                enable()
            } else {
                disable()
            }
        }
    }

    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func enable() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            isEnabled = false
        }
    }

    private func disable() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    /// Refresh the status from the system
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
