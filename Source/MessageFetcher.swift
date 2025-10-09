//
//  MessageFetcher.swift
//  Mail Notifr
//
//  Created by James Chen on 2021/06/23.
//  Copyright © 2021 ashchan.com. All rights reserved.
//

import Foundation
import AppAuth
import GTMAppAuth
import GoogleAPIClientForREST_Gmail

extension Notification.Name {
    static let unreadCountUpdated = Notification.Name("unreadCountUpdated")
    static let messagesFetched = Notification.Name("messagesFetched")
}

final class MessageFetcher: NSObject {
    var account: Account
    private var authorization: GTMAppAuthFetcherAuthorization? {
        didSet {
            authorization?.authState.stateChangeDelegate = self
        }
    }
    private var authState: OIDAuthState? {
        didSet {
            authState?.stateChangeDelegate = self
        }
    }
    private var timer: Timer?
    private(set) var hasAuthError = false

    private(set) var lastCheckedAt = Date()
    private(set) var hasNewMessages = false

    private(set) var unreadMessagesCount = 0 {
        didSet {
            NotificationCenter.default.post(name: .unreadCountUpdated, object: account.email)
        }
    }
    private let maximumMessagesStored = 10
    private let defaultLabel = "INBOX"

    private(set) var messages = [Message]() {
        didSet {
            if let newestMessage = messages.first {
                if let newestMessageDate = account.newestMessageDate {
                    hasNewMessages = newestMessage.serverDate > newestMessageDate
                } else {
                    hasNewMessages = true
                }
                account.newestMessageDate = newestMessage.serverDate
                Accounts.default.update(account: account)
            } else {
                hasNewMessages = false
            }
            NotificationCenter.default.post(name: .messagesFetched, object: account.email)
        }
    }

    init(account: Account) {
        self.account = account
    }

    // Fetch and store at most `maximumMessagesStored` messages.
    @objc func fetch() {
        reschedule()
        switch account.type {
        case .gmail:
            authorization = account.authorization
            if authorization != nil {
                hasAuthError = false
                fetchUnreadCount()
                fetchMessages()
                lastCheckedAt = Date()
            } else {
                hasAuthError = true
                unreadMessagesCount = 0
                messages = []
            }
        case .outlook:
            // Always reload the auth state from the account to pick up any OAuth updates
            authState = account.authState
            if let _ = authState {
                hasAuthError = false
                fetchUnreadCount()
                fetchMessages()
                lastCheckedAt = Date()
            } else {
                hasAuthError = true
                unreadMessagesCount = 0
                messages = []
            }
        }
    }

    func reschedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: account.checkInterval * 60,
            target: self,
            selector: #selector(fetch),
            userInfo: nil,
            repeats: false
        )
    }

    func cleanUp() {
        timer?.invalidate()
        authorization?.authState.stateChangeDelegate = nil
        authState?.stateChangeDelegate = nil
    }
}

extension MessageFetcher: OIDAuthStateChangeDelegate {
    func didChange(_ state: OIDAuthState) {
        switch account.type {
        case .gmail:
            account.authorization = GTMAppAuthFetcherAuthorization(authState: state)
            authorization = account.authorization
        case .outlook:
            account.authState = state
            authState = state
        }
    }
}

private extension MessageFetcher {
    func fetchUnreadCount() {
        if account.type == .gmail {
            guard let authorization = authorization, !hasAuthError else { return }
            let query = GTLRGmailQuery_UsersLabelsGet.query(withUserId: authorization.userEmail ?? "me", identifier: defaultLabel)
            let service = GTLRGmailService()
            service.authorizer = authorization
            service.executeQuery(query) { [weak self] _, result, error in
                if let label = result as? GTLRGmail_Label, error == nil {
                    self?.unreadMessagesCount = label.messagesUnread?.intValue ?? 0
                } else {
                    self?.hasAuthError = true
                }
            }
        } else {
            guard let authState = authState, let accessToken = authState.lastTokenResponse?.accessToken, !hasAuthError else {
                print("⚠️ Cannot fetch unread count - no auth state or access token")
                return
            }
            print("📊 Fetching unread count for \(account.email)")
            NSLog("📊 Fetching unread count for \(account.email)")
            var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/mailFolders/Inbox?$select=unreadItemCount")!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Unread count fetch error: \(error)")
                    DispatchQueue.main.async { self.hasAuthError = true }
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    NSLog("📊 Unread count response status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 401 {
                        NSLog("❌ Unauthorized - token may be expired")
                        DispatchQueue.main.async { self.hasAuthError = true }
                        return
                    }
                }
                if let data = data {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        NSLog("📊 Unread count response: \(json)")
                        if let count = json["unreadItemCount"] as? Int {
                            NSLog("✅ Unread count: \(count)")
                            DispatchQueue.main.async { self.unreadMessagesCount = count }
                        } else {
                            NSLog("❌ No unreadItemCount in response")
                            DispatchQueue.main.async { self.hasAuthError = true }
                        }
                    } else {
                        NSLog("❌ Failed to parse unread count JSON")
                        if let responseString = String(data: data, encoding: .utf8) {
                            NSLog("Response: \(responseString)")
                        }
                        DispatchQueue.main.async { self.hasAuthError = true }
                    }
                }
            }.resume()
        }
    }

    func fetchMessages() {
        if account.type == .gmail {
            guard let authorization = authorization, !hasAuthError else { return }
            let query = GTLRGmailQuery_UsersMessagesList.query(withUserId: authorization.userEmail ?? "me")
            query.q = "is:unread"
            query.labelIds = [defaultLabel]
            query.maxResults = UInt(maximumMessagesStored)
            let service = GTLRGmailService()
            service.authorizer = authorization
            service.executeQuery(query) { [weak self] _, result, error in
                if let list = result as? GTLRGmail_ListMessagesResponse, error == nil {
                    if let messages = list.messages {
                        self?.fetchMessages(for: messages.compactMap { $0.identifier })
                    } else {
                        self?.storeMessages([])
                    }
                } else {
                    self?.hasAuthError = true
                }
            }
        } else {
            guard let authState = authState, let accessToken = authState.lastTokenResponse?.accessToken, !hasAuthError else {
                print("⚠️ Cannot fetch messages - no auth state or access token")
                return
            }
            print("📧 Fetching messages for \(account.email)")
            var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/mailFolders/Inbox/messages")!
            components.queryItems = [
                URLQueryItem(name: "$filter", value: "isRead eq false"),
                URLQueryItem(name: "$top", value: "\(maximumMessagesStored)"),
                URLQueryItem(name: "$select", value: "id,subject,bodyPreview,from,receivedDateTime")
            ]
            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("📧 Request URL: \(components.url?.absoluteString ?? "invalid")")
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Messages fetch error: \(error)")
                    DispatchQueue.main.async { self.hasAuthError = true }
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("📧 Messages response status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 401 {
                        print("❌ Unauthorized - token may be expired")
                        DispatchQueue.main.async { self.hasAuthError = true }
                        return
                    }
                }
                guard let data = data else {
                    print("❌ No data in response")
                    DispatchQueue.main.async { self.hasAuthError = true }
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ Failed to parse messages JSON")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                    DispatchQueue.main.async { self.hasAuthError = true }
                    return
                }

                print("📧 Messages response: \(json.keys)")

                guard let value = json["value"] as? [[String: Any]] else {
                    print("❌ No 'value' array in response")
                    DispatchQueue.main.async { self.hasAuthError = true }
                    return
                }

                NSLog("✅ Found \(value.count) messages")
                let msgs = value.compactMap { self.parseOutlookMessage($0) }
                NSLog("✅ Parsed \(msgs.count) messages successfully")
                DispatchQueue.main.async {
                    NSLog("✅ Setting messages array with \(msgs.count) messages")
                    self.messages = msgs
                }
            }.resume()
        }
    }

    func fetchMessages(for ids: [String]) {
        guard account.type == .gmail else { return }
        guard let authorization = authorization, !hasAuthError else { return }
        let batchQuery = GTLRBatchQuery()
        for id in ids {
            let query = GTLRGmailQuery_UsersMessagesGet.query(withUserId: authorization.userEmail ?? "me", identifier: id)
            query.fields = "id, snippet, payload(headers), internalDate"
            batchQuery.addQuery(query)
        }
        let service = GTLRGmailService()
        service.authorizer = authorization
        service.executeQuery(batchQuery) { [weak self] _, result, error in
            if let batchResult = result as? GTLRBatchResult,
               let messages = batchResult.successes as? [String: GTLRGmail_Message] {
                self?.storeMessages(messages.values.map({ $0 }))
            } else {
                self?.hasAuthError = true
            }
        }
    }

    func storeMessages(_ gmailMessages: [GTLRGmail_Message]) {
        messages = gmailMessages.map { msg in
            let headers = msg.payload?.headers ?? [GTLRGmail_MessagePartHeader]()
            func findValue(by name: String) -> String {
                headers.first(where: { $0.name == name })?.value ?? ""
            }

            return Message(
                id: msg.identifier ?? "",
                email: account.email,
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

    func parseOutlookMessage(_ json: [String: Any]) -> Message? {
        guard let id = json["id"] as? String else { return nil }
        let from = ((json["from"] as? [String: Any])?["emailAddress"] as? [String: Any])?["name"] as? String ?? ""
        let subject = json["subject"] as? String ?? ""
        let snippet = json["bodyPreview"] as? String ?? ""
        let dateStr = json["receivedDateTime"] as? String ?? ""
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: dateStr)?.timeIntervalSince1970 ?? 0
        return Message(id: id, email: account.email, type: .outlook, from: from, date: dateStr, subject: subject, snippet: snippet, internalDate: date * 1000)
    }
}
