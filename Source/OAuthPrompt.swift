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
        VStack {
            Image("Oauth-Prompt")
                .resizable()
                .scaledToFit()

            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                }

                Button {
                    dismiss()
                    Accounts.authorize(type: Self.accountType)
                } label: {
                    Text("Continue")
                }
            }
        }
        .padding()
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
