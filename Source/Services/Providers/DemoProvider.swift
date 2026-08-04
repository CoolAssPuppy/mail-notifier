//
//  DemoProvider.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//
//  The mail provider demo mode installs in place of Gmail and Outlook. It
//  answers from a fixed script instead of the network, so screenshots show the
//  same inboxes every time, need no credentials, and never touch real mail.
//

import AppAuth
import Foundation

final class DemoProvider: NSObject, MailProvider {
    let accountEmail: String

    init(account: Account) {
        self.accountEmail = account.email
    }

    func fetchUnreadCount(completion: @escaping (Result<Int, MailProviderError>) -> Void) {
        completion(.success(DemoInbox.messages(for: accountEmail).count))
    }

    func fetchMessages(limit: Int, completion: @escaping (Result<[Message], MailProviderError>) -> Void) {
        completion(.success(Array(DemoInbox.messages(for: accountEmail).prefix(limit))))
    }

    /// Nothing to update: a demo account carries no tokens.
    func updateCredentials(from account: Account) {}

    func cleanUp() {}

    func didChange(_ state: OIDAuthState) {}
}

// MARK: - The script

/// The fake inboxes. Every string a screenshot can show lives here.
enum DemoInbox {

    /// The accounts demo mode seeds on first use. Two providers so the sidebar
    /// shows both brand icons, and three accounts so the multi-account layout
    /// has something to lay out.
    static let accounts: [Account] = [
        Account(email: "prashant@gmail.com", type: .gmail),
        Account(email: "hello@strategicnerds.com", type: .gmail),
        Account(email: "prashant@outlook.com", type: .outlook)
    ]

    /// Newest first, which is the order every real provider returns.
    static func messages(for email: String) -> [Message] {
        let key = email.lowercased()
        let type = accounts.first { $0.email.lowercased() == key }?.type ?? .gmail
        return script[key, default: []].enumerated().map { index, item in
            let sentAt = Date().addingTimeInterval(-item.minutesAgo * 60)
            return Message(
                id: "demo-\(key)-\(index)",
                email: email,
                type: type,
                from: item.from,
                date: Formatters.longDate.string(from: sentAt),
                subject: item.subject,
                snippet: item.snippet,
                internalDate: sentAt.timeIntervalSince1970 * 1000
            )
        }
    }

    private struct Item {
        let from: String
        let subject: String
        let snippet: String
        let minutesAgo: Double
    }

    private static let script: [String: [Item]] = [
        "prashant@gmail.com": [
            Item(from: "Maya Okonkwo <maya@okonkwo.studio>",
                 subject: "Re: the Lisbon photos",
                 snippet: "These came out so much better than the ones from last summer. The one on the tram especially.",
                 minutesAgo: 4),
            Item(from: "Apple <no_reply@email.apple.com>",
                 subject: "Your receipt from Apple",
                 snippet: "iCloud+ 2TB, monthly. Billed to the card ending in 4412.",
                 minutesAgo: 26),
            Item(from: "Dad <robert.s@icloud.com>",
                 subject: "Sunday",
                 snippet: "Your mother wants to know if you're bringing anyone. I said I would ask. I have asked.",
                 minutesAgo: 91),
            Item(from: "Linear <notifications@linear.app>",
                 subject: "MN-142 was moved to Done",
                 snippet: "Classic menu follows the system appearance. Closed by Prashant Sridharan.",
                 minutesAgo: 187)
        ],
        "hello@strategicnerds.com": [
            Item(from: "Yuki Tanaka <yuki@parallelpress.jp>",
                 subject: "Translation pass on the release notes",
                 snippet: "Japanese and Korean are done. The Klingon one made my week, but I have questions.",
                 minutesAgo: 12),
            Item(from: "Polar <support@polar.sh>",
                 subject: "New subscription: Mail Notifier Pro",
                 snippet: "A customer subscribed at $6.00 per year. Your payout balance has been updated.",
                 minutesAgo: 58)
        ],
        "prashant@outlook.com": [
            Item(from: "Priya Raghunathan <p.raghunathan@northbay.co>",
                 subject: "Thursday's review, moved",
                 snippet: "Pushing to 4pm so the Berlin folks can make it. Same link. Sorry for the churn.",
                 minutesAgo: 7),
            Item(from: "GitHub <noreply@github.com>",
                 subject: "[CoolAssPuppy/mail-notifier] 2 new issues",
                 snippet: "Unread badge lags by one fetch on wake. Also: request for a Fastmail provider.",
                 minutesAgo: 33),
            Item(from: "Ana Sofia Reis <ana@atelierbaixa.pt>",
                 subject: "Chaves novas",
                 snippet: "Deixei o segundo conjunto com o porteiro. Ele sai às sete, portanto avisa antes.",
                 minutesAgo: 74),
            Item(from: "Cloudflare <noreply@notify.cloudflare.com>",
                 subject: "R2 usage summary",
                 snippet: "strategic-nerds-downloads served 3,104 requests this week. Well inside the free tier.",
                 minutesAgo: 140),
            Item(from: "Marcus Bell <marcus@ninthfloor.io>",
                 subject: "That thing you sent",
                 snippet: "I read it twice. Second time was better. Call me when you're back from Portugal.",
                 minutesAgo: 205)
        ]
    ]
}
