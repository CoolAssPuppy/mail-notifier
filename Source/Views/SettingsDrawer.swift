//
//  SettingsDrawer.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct SettingsDrawer: View {
    @Binding var isPresented: Bool
    var contentHeight: CGFloat = 600

    var body: some View {
        ZStack(alignment: .top) {
            if isPresented {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)

                drawer
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .background(EscapeKeyMonitor(isActive: isPresented, onEscape: close))
            }
        }
        .animation(.easeOut(duration: 0.26), value: isPresented)
    }

    private var drawer: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 1)

            ScrollView { SettingsView() }
                .frame(maxHeight: contentHeight)

            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 1)

            footer
        }
        .background(Color.appSurface)
        .overlay(drawerShape.strokeBorder(Color.appBorder, lineWidth: 1))
        .clipShape(drawerShape)
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }

    private var drawerShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(topLeading: 0, bottomLeading: 14,
                               bottomTrailing: 14, topTrailing: 0),
            style: .continuous
        )
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.appForeground)
                Text("Preferences for Mail Notifier · ⌘, to toggle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted)
            }

            Spacer()

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.appForeground)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.appCard))
                    .overlay(Circle().strokeBorder(Color.appBorderStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text("Made with")
                .font(.system(size: 10))
                .foregroundStyle(Color.appTertiary)
            Image(systemName: "heart.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.appDestructive)
            Text("in Lisbon by Strategic Nerds")
                .font(.system(size: 10))
                .foregroundStyle(Color.appTertiary)
            Circle().fill(Color.appDim).frame(width: 3, height: 3).padding(.horizontal, 4)
            Text("© 2026")
                .font(.system(size: 10))
                .foregroundStyle(Color.appTertiary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.appBackground)
    }

    private func close() {
        isPresented = false
    }
}

// MARK: - Escape key listener

private struct EscapeKeyMonitor: NSViewRepresentable {
    let isActive: Bool
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyMonitorView {
        let view = KeyMonitorView()
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyMonitorView, context: Context) {
        nsView.onEscape = onEscape
        guard isActive, let window = nsView.window else { return }
        // Only grab focus once per appearance; otherwise we steal focus from
        // TextFields inside the drawer on every parent re-render.
        if window.firstResponder !== nsView && !(window.firstResponder is NSTextView) {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder !== nsView &&
                   !(nsView.window?.firstResponder is NSTextView) {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }
    }
}

private final class KeyMonitorView: NSView {
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        // Pass through anything else so text input keeps working when a
        // field inside the drawer is focused after our initial responder grab.
        nextResponder?.keyDown(with: event)
    }
}
