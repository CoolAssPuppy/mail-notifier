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
            if let error {
                completion(.failure(Self.mapGmailError(error)))
                return
            }
            guard let label = result as? GTLRGmail_Label else {
                completion(.failure(.parsingError("Unexpected response type for label fetch")))
                return
            }
            completion(.success(label.messagesUnread?.intValue ?? 0))
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
            if let error {
                completion(.failure(Self.mapGmailError(error)))
                return
            }
            guard let list = result as? GTLRGmail_ListMessagesResponse else {
                completion(.failure(.parsingError("Unexpected response type for message list")))
                return
            }
            guard let messages = list.messages else {
                completion(.success([]))
                return
            }
            self?.fetchMessageDetails(
                ids: messages.compactMap { $0.identifier },
                completion: completion
            )
        }
    }
}

// MARK: - Error mapping

extension GmailProvider {
    /// Maps an `NSError` from the Google API client to the app's
    /// `MailProviderError` taxonomy. Previously every failure was flattened to
    /// `.authenticationRequired`, which painted transient network errors as
    /// "Auth expired" in the UI.
    static func mapGmailError(_ error: Error) -> MailProviderError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .networkError(error)
        }
        if let httpStatus = httpStatusCode(from: nsError) {
            if httpStatus == 401 || httpStatus == 403 {
                return .authenticationRequired
            }
            return .httpError(statusCode: httpStatus)
        }
        return .parsingError(error.localizedDescription)
    }

    /// Pulls an HTTP status code from a Google API client error. Tries the
    /// structured error object first, then falls back to the NSError code if
    /// the domain is the GTLR error domain.
    private static func httpStatusCode(from error: NSError) -> Int? {
        if let underlying = GTLRErrorObject.underlyingObject(forError: error),
           let code = underlying.code {
            return code.intValue
        }
        if error.domain == kGTLRErrorObjectDomain {
            return error.code
        }
        return nil
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
            if let error {
                completion(.failure(Self.mapGmailError(error)))
                return
            }
            guard let batchResult = result as? GTLRBatchResult,
                  let gmailMessages = batchResult.successes as? [String: GTLRGmail_Message] else {
                completion(.failure(.parsingError("Unexpected response type for batch message fetch")))
                return
            }
            let messages = self.convertMessages(gmailMessages.values.map { $0 })
            completion(.success(messages))
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
