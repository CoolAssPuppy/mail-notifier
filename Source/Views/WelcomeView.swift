//
//  WelcomeView.swift
//  Mail Notifier
//

//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 24) {
                HStack(spacing: 24) {
                    Image(nsImage: NSImage(named: "AppIcon")!)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.secondary)

                    Image(systemName: "person.crop.circle.badge.plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Welcome to Mail Notifier")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text("Get started by connecting your email account")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 12) {
                Button(action: { addAccount(.gmail) }) {
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Add Google Account")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: { addAccount(.outlook) }) {
                    HStack(spacing: 12) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Add Outlook Account")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.03),
                    Color.clear,
                    Color.blue.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial)
    }

    private func addAccount(_ type: AccountType) {
        Accounts.authorize(type: type)
    }
}

#Preview {
    WelcomeView()
}
