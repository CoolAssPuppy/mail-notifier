//
//  OAuthPrompt.swift
//  MailNotifr
//
//  Created by James Chen on 2021/10/22.
//  Copyright © 2021 ashchan.com. All rights reserved.
//

import SwiftUI

struct OAuthPrompt: View {
    @Environment(\.presentationMode) var presentationMode
    static var accountType: AccountType = .gmail

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image("Oauth-Prompt")
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Divider()

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Spacer()

                Button {
                    dismiss()
                    Accounts.authorize(type: Self.accountType)
                } label: {
                    Text("Continue")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(.regularMaterial)
        }
        .background(.ultraThinMaterial)
        .frame(width: 800, height: 650)
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct OAuthPrompt_Previews: PreviewProvider {
    static var previews: some View {
        OAuthPrompt()
    }
}
