//
//  Message.swift
//  Mail Notifier
//

//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
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
            var components = URLComponents()
            components.scheme = "https"
            components.host = "mail.google.com"
            let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? email
            components.percentEncodedPath = "/mail/u/\(encodedEmail)"
            components.queryItems = [
                URLQueryItem(name: "account_id", value: email),
                URLQueryItem(name: "message_id", value: id),
                URLQueryItem(name: "view", value: "conv"),
                URLQueryItem(name: "extsrc", value: "atom")
            ]
            return components.url ?? URL(string: "https://mail.google.com")!
        case .outlook:
            var components = URLComponents()
            components.scheme = "https"
            components.host = "outlook.live.com"
            let encodedMessageID = id.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? id
            components.percentEncodedPath = "/mail/0/inbox/id/\(encodedMessageID)"
            return components.url ?? URL(string: "https://outlook.live.com/mail/0/inbox")!
        }
    }

    var decodedSnippet: String {
        CFXMLCreateStringByUnescapingEntities(nil, snippet as CFString, nil) as String
    }
}

private extension CharacterSet {
    static let urlPathComponentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/")
        return set
    }()
}
