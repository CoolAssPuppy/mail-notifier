//
//  GmailProvider.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import AppAuth
import GTMAppAuth
import GoogleAPIClientForREST_Gmail

final class GmailProvider: NSObject, MailProvider {
    let accountEmail: String
    private let defaultLabel = "INBOX"
    private var authorization: GTMAppAuthFetcherAuthorization? {
        didSet {
            authorization?.authState.stateChangeDelegate = self
        }
    }

    init(account: Account) {
        self.accountEmail = account.email
        super.init()
        self.authorization = account.authorization
    }

    func updateCredentials(from account: Account) {
        authorization = account.authorization
    }

    func cleanUp() {
        authorization?.authState.stateChangeDelegate = nil
    }

    func didChange(_ state: OIDAuthState) {
        guard var account = Accounts.default.find(email: accountEmail) else { return }
        let newAuth = GTMAppAuthFetcherAuthorization(authState: state)
        account.authorization = newAuth
        Accounts.default.update(account: account)
        authorization = newAuth
    }

    func fetchUnreadCount(completion: @escaping (Result<Int, MailProviderError>) -> Void) {
        guard let authorization else {
            completion(.failure(.authenticationRequired))
            return
        }

        let query = GTLRGmailQuery_UsersLabelsGet.query(
            withUserId: authorization.userEmail ?? "me",
            identifier: defaultLabel
        )
        let service = GTLRGmailService()
        service.authorizer = authorization

        service.executeQuery(query) { _, result, error in
            if let label = result as? GTLRGmail_Label, error == nil {
                completion(.success(label.messagesUnread?.intValue ?? 0))
            } else {
                completion(.failure(.authenticationRequired))
            }
        }
    }

    func fetchMessages(limit: Int, completion: @escaping (Result<[Message], MailProviderError>) -> Void) {
        guard let authorization else {
            completion(.failure(.authenticationRequired))
            return
        }

        let query = GTLRGmailQuery_UsersMessagesList.query(withUserId: authorization.userEmail ?? "me")
        query.q = "is:unread"
        query.labelIds = [defaultLabel]
        query.maxResults = UInt(limit)

        let service = GTLRGmailService()
        service.authorizer = authorization

        service.executeQuery(query) { [weak self] _, result, error in
            if let list = result as? GTLRGmail_ListMessagesResponse, error == nil {
                if let messages = list.messages {
                    self?.fetchMessageDetails(
                        ids: messages.compactMap { $0.identifier },
                        completion: completion
                    )
                } else {
                    completion(.success([]))
                }
            } else {
                completion(.failure(.authenticationRequired))
            }
        }
    }
}

// MARK: - Private

private extension GmailProvider {
    func fetchMessageDetails(ids: [String], completion: @escaping (Result<[Message], MailProviderError>) -> Void) {
        guard let authorization else {
            completion(.failure(.authenticationRequired))
            return
        }

        let batchQuery = GTLRBatchQuery()
        for id in ids {
            let query = GTLRGmailQuery_UsersMessagesGet.query(
                withUserId: authorization.userEmail ?? "me",
                identifier: id
            )
            query.fields = "id, snippet, payload(headers), internalDate"
            batchQuery.addQuery(query)
        }

        let service = GTLRGmailService()
        service.authorizer = authorization

        service.executeQuery(batchQuery) { [weak self] _, result, error in
            guard let self else { return }
            if let batchResult = result as? GTLRBatchResult,
               let gmailMessages = batchResult.successes as? [String: GTLRGmail_Message] {
                let messages = self.convertMessages(gmailMessages.values.map { $0 })
                completion(.success(messages))
            } else {
                completion(.failure(.authenticationRequired))
            }
        }
    }

    func convertMessages(_ gmailMessages: [GTLRGmail_Message]) -> [Message] {
        gmailMessages.map { msg in
            let headers = msg.payload?.headers ?? [GTLRGmail_MessagePartHeader]()
            func findValue(by name: String) -> String {
                headers.first(where: { $0.name == name })?.value ?? ""
            }

            return Message(
                id: msg.identifier ?? "",
                email: accountEmail,
                type: .gmail,
                from: findValue(by: "From"),
                date: findValue(by: "Date"),
                subject: findValue(by: "Subject"),
                snippet: msg.snippet ?? "",
                internalDate: msg.internalDate?.doubleValue ?? 0
            )
        }
        .sorted(by: { $0.internalDate > $1.internalDate })
    }
}
