//
//  OutlookProvider.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import AppAuth

// MARK: - Microsoft Graph API Response Types

private struct OutlookMailFolderResponse: Decodable {
    let unreadItemCount: Int
}

private struct OutlookMessagesResponse: Decodable {
    let value: [OutlookMessageDTO]
}

private struct OutlookMessageDTO: Decodable {
    let id: String
    let subject: String?
    let bodyPreview: String?
    let receivedDateTime: String?
    let from: OutlookFrom?
}

private struct OutlookFrom: Decodable {
    let emailAddress: OutlookEmailAddress?
}

private struct OutlookEmailAddress: Decodable {
    let name: String?
    let address: String?
}

// MARK: - OutlookProvider

final class OutlookProvider: NSObject, MailProvider {
    let accountEmail: String
    private var authState: OIDAuthState? {
        didSet {
            authState?.stateChangeDelegate = self
        }
    }

    init(account: Account) {
        self.accountEmail = account.email
        super.init()
        self.authState = account.authState
    }

    func updateCredentials(from account: Account) {
        authState = account.authState
    }

    func cleanUp() {
        authState?.stateChangeDelegate = nil
    }

    func didChange(_ state: OIDAuthState) {
        var account = Account(email: accountEmail, type: .outlook)
        account.authState = state
        authState = state
    }

    func fetchUnreadCount(completion: @escaping (Result<Int, MailProviderError>) -> Void) {
        performAuthorizedRequest(
            url: "https://graph.microsoft.com/v1.0/me/mailFolders/Inbox?$select=unreadItemCount"
        ) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(OutlookMailFolderResponse.self, from: data)
                    completion(.success(response.unreadItemCount))
                } catch {
                    completion(.failure(.parsingError("Failed to decode unread count: \(error.localizedDescription)")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchMessages(limit: Int, completion: @escaping (Result<[Message], MailProviderError>) -> Void) {
        var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/mailFolders/Inbox/messages")!
        components.queryItems = [
            URLQueryItem(name: "$filter", value: "isRead eq false"),
            URLQueryItem(name: "$top", value: "\(limit)"),
            URLQueryItem(name: "$select", value: "id,subject,bodyPreview,from,receivedDateTime")
        ]

        guard let url = components.url else {
            completion(.failure(.parsingError("Failed to construct messages URL")))
            return
        }

        performAuthorizedRequest(url: url.absoluteString) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(OutlookMessagesResponse.self, from: data)
                    let messages = response.value.map { self.convertMessage($0) }
                    completion(.success(messages))
                } catch {
                    completion(.failure(.parsingError("Failed to decode messages: \(error.localizedDescription)")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Private

private extension OutlookProvider {
    func performAuthorizedRequest(url: String, completion: @escaping (Result<Data, MailProviderError>) -> Void) {
        guard let authState else {
            completion(.failure(.authenticationRequired))
            return
        }

        authState.performAction { accessToken, _, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let accessToken else {
                DispatchQueue.main.async {
                    completion(.failure(.authenticationRequired))
                }
                return
            }

            var request = URLRequest(url: URL(string: url)!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    DispatchQueue.main.async {
                        completion(.failure(.networkError(error)))
                    }
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    DispatchQueue.main.async {
                        completion(.failure(.authenticationRequired))
                    }
                    return
                }

                guard let data else {
                    DispatchQueue.main.async {
                        completion(.failure(.parsingError("No data received")))
                    }
                    return
                }

                DispatchQueue.main.async {
                    completion(.success(data))
                }
            }.resume()
        }
    }

    func convertMessage(_ dto: OutlookMessageDTO) -> Message {
        let dateStr = dto.receivedDateTime ?? ""
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: dateStr)?.timeIntervalSince1970 ?? 0

        return Message(
            id: dto.id,
            email: accountEmail,
            type: .outlook,
            from: dto.from?.emailAddress?.name ?? "",
            date: dateStr,
            subject: dto.subject ?? "",
            snippet: dto.bodyPreview ?? "",
            internalDate: date * 1000
        )
    }
}
