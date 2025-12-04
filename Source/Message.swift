//
//  Message.swift
//  Mail Notifier
//
//  Created by James Chen on 2021/06/23.
//  Copyright © 2021 ashchan.com. All rights reserved.
//

import Foundation

struct Message {
    let id: String
    let email: String
    let type: AccountType
    let from: String
    let date: String
    let subject: String
    let snippet: String
    let internalDate: TimeInterval

    var sender: String {
        let result = from.split(separator: "<").first ?? Substring(from)
        return result
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: ["\"", "\\"])
    }

    var senderEmail: String {
        // Extract email from format like "Name <email@example.com>" or just "email@example.com"
        if let start = from.firstIndex(of: "<"),
           let end = from.firstIndex(of: ">") {
            return String(from[from.index(after: start)..<end]).lowercased()
        }
        // If no angle brackets, assume the whole string is the email
        return from.trimmingCharacters(in: .whitespaces).lowercased()
    }

    var serverDate: Date {
        Date(timeIntervalSince1970: internalDate / 1000)
    }

    var url: URL {
        Self.url(type: type, email: email, id: id)
    }

    static func url(type: AccountType, email: String, id: String) -> URL {
        switch type {
        case .gmail:
            return URL(string: "https://mail.google.com/mail/u/\(email)?account_id=\(email)&message_id=\(id)&view=conv&extsrc=atom")!
        case .outlook:
            return URL(string: "https://outlook.live.com/mail/0/inbox/id/\(id)")!
        }
    }

    var decodedSnippet: String {
        CFXMLCreateStringByUnescapingEntities(nil, snippet as CFString, nil) as String
    }
}
