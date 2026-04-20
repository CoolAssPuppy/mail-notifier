//
//  MailProvider.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import AppAuth

enum MailProviderError: Error {
    case authenticationRequired
    case networkError(Error)
    case httpError(statusCode: Int)
    case parsingError(String)
}

protocol MailProvider: OIDAuthStateChangeDelegate {
    var accountEmail: String { get }
    func fetchUnreadCount(completion: @escaping (Result<Int, MailProviderError>) -> Void)
    func fetchMessages(limit: Int, completion: @escaping (Result<[Message], MailProviderError>) -> Void)
    func updateCredentials(from account: Account)
    func cleanUp()
}
