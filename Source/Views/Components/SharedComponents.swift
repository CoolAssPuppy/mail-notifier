//
//  SharedComponents.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let icon: String
    let title: String
    let gradient: [Color]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let image: String
    let backgroundColor: Color

    var body: some View {
        Circle()
            .frame(width: 24, height: 24)
            .foregroundColor(backgroundColor)
            .overlay(
                Image(systemName: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Previews

#Preview("Section Header") {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeader(icon: "gearshape.fill", title: "General", gradient: [.blue, .cyan])
        SectionHeader(icon: "bell.fill", title: "Notifications", gradient: [.orange, .red])
        SectionHeader(icon: "star.fill", title: "VIP List", gradient: [.yellow, .orange])
    }
    .padding()
}

#Preview("Avatar View") {
    HStack(spacing: 12) {
        AvatarView(image: "g.circle.fill", backgroundColor: .red)
        AvatarView(image: "cloud.fill", backgroundColor: .blue)
        AvatarView(image: "gearshape.fill", backgroundColor: .gray)
    }
    .padding()
}
