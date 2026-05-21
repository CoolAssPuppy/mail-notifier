//
//  NotificationService.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation
import UserNotifications

protocol NotificationServiceDelegate: AnyObject {
    func notificationService(_ service: NotificationService, didRequestOpenMessage messageId: String, email: String)
}

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    weak var delegate: NotificationServiceDelegate?

    func setup() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
                if granted {
                    await MainActor.run {
                        UNUserNotificationCenter.current().delegate = self
                    }
                }
            } catch {
                Log.app.error("Failed to request notification authorization: \(error.localizedDescription)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])

        let userInfo = response.notification.request.content.userInfo
        let isVIP = (userInfo["isVIP"] as? Bool) ?? false
        Telemetry.capture("notification.clicked", properties: ["is_vip": isVIP])

        if let messageId = userInfo["messageId"] as? String,
           let email = userInfo["email"] as? String {
            delegate?.notificationService(self, didRequestOpenMessage: messageId, email: email)
        }

        completionHandler()
    }

    func deliverNotifications(for messages: [Message], account: Account) {
        Task {
            let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
            let deliveredIds = Set(delivered.map { $0.request.identifier })
            let vipList = VIPList.default

            // Resolve a single sound for this batch so a fetch makes one sound,
            // matching the previous NSSound behavior: a VIP sender's sound wins,
            // otherwise the account's sound. Attaching it to the notification
            // (instead of calling NSSound.play) lets macOS play it, so Focus /
            // Do Not Disturb governs the sound the same way it governs the banner.
            let batchSound = messages.lazy
                .compactMap { vipList.soundForSender($0.senderEmail) }
                .first ?? account.sound

            let newMessages = messages.filter { !deliveredIds.contains(notificationIdentifier(for: $0)) }

            for (index, message) in newMessages.enumerated() {
                let isVIP = vipList.soundForSender(message.senderEmail) != nil
                let content = UNMutableNotificationContent()
                content.title = message.sender
                content.subtitle = message.subject
                content.body = message.decodedSnippet
                content.userInfo = ["messageId": message.id, "email": message.email, "isVIP": isVIP]
                content.threadIdentifier = message.email
                // One sound per batch: only the first delivered notification carries it.
                if index == 0, let batchSound {
                    content.sound = batchSound.notificationSound
                }

                let request = UNNotificationRequest(identifier: notificationIdentifier(for: message), content: content, trigger: nil)
                do {
                    try await UNUserNotificationCenter.current().add(request)
                    Telemetry.capture("notification.shown", properties: ["is_vip": isVIP])
                } catch {
                    Log.app.error("Failed to deliver notification for message \(message.id): \(error.localizedDescription)")
                }
            }
        }
    }

    private func notificationIdentifier(for message: Message) -> String {
        "\(message.type.rawValue):\(message.email.lowercased()):\(message.id)"
    }

    func handleMessagesFetched(email: String, fetcherManager: FetcherManager) {
        guard let account = Accounts.default.find(email: email), account.enabled,
              let fetcher = fetcherManager.fetcher(for: email),
              fetcher.hasNewMessages,
              account.notificationEnabled else { return }

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
                  settings.alertSetting == .enabled else { return }

            // The sound rides on the notification (see deliverNotifications) so
            // macOS plays it and Focus governs it. We no longer play it directly
            // with NSSound, which bypassed Focus entirely.
            deliverNotifications(for: fetcher.messages, account: account)
        }
    }
}
