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
    private let suppressedNotifications = SuppressedNotificationStore()

    func setup() {
        Task {
            do {
                // .sound is required now that the notification carries the sound
                // (previously the sound was played directly via NSSound, which
                // needs no notification permission). Without .sound the system
                // shows the banner but stays silent.
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
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
        Telemetry.capture(.notificationClicked, properties: ["is_vip": isVIP])

        if let messageId = userInfo["messageId"] as? String,
           let email = userInfo["email"] as? String {
            delegate?.notificationService(self, didRequestOpenMessage: messageId, email: email)
        }

        completionHandler()
    }

    func deliverNotifications(for messages: [Message], account: Account) {
        Task {
            if AppSettings.shared.quietHours.contains(Date()) {
                suppressedNotifications.mark(messages.map(notificationIdentifier(for:)))
                return
            }

            let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
            let deliveredIds = Set(delivered.map { $0.request.identifier })
            let vipList = VIPList.default

            let quietHours = AppSettings.shared.quietHours
            let candidates = messages.filter {
                let identifier = notificationIdentifier(for: $0)
                return !deliveredIds.contains(identifier) && !suppressedNotifications.contains(identifier)
            }
            let skipped = candidates.filter { message in
                let receivedAt = message.internalDate > 0 ? message.serverDate : nil
                return quietHours.shouldSuppress(receivedAt: receivedAt, deliveredAt: Date())
            }
            suppressedNotifications.mark(skipped.map(notificationIdentifier(for:)))
            let newMessages = candidates.filter { message in
                !suppressedNotifications.contains(notificationIdentifier(for: message))
            }

            // A VIP sound wins among the messages that will be shown. One sound
            // per batch lets macOS Focus govern both the banner and its sound.
            let batchSound = newMessages.lazy
                .compactMap { vipList.soundForSender($0.senderEmail) }
                .first ?? account.sound

            for (index, message) in newMessages.enumerated() {
                if AppSettings.shared.quietHours.contains(Date()) {
                    suppressedNotifications.mark(newMessages[index...].map(notificationIdentifier(for:)))
                    return
                }
                let isVIP = vipList.soundForSender(message.senderEmail) != nil
                let content = UNMutableNotificationContent()
                content.title = message.sender
                content.subtitle = message.subject
                content.body = message.decodedSnippet
                content.userInfo = ["messageId": message.id, "email": message.email, "isVIP": isVIP]
                content.threadIdentifier = message.email
                // One sound per batch: only the first delivered notification carries it.
                // Falls back to the default sound if staging the custom file fails.
                if index == 0, let batchSound {
                    content.sound = batchSound.notificationSound() ?? .default
                }

                let request = UNNotificationRequest(identifier: notificationIdentifier(for: message), content: content, trigger: nil)
                do {
                    try await UNUserNotificationCenter.current().add(request)
                    Telemetry.capture(.notificationShown, properties: ["is_vip": isVIP])
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
