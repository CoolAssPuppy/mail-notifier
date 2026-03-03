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
        if let messageId = userInfo["messageId"] as? String,
           let email = userInfo["email"] as? String {
            delegate?.notificationService(self, didRequestOpenMessage: messageId, email: email)
        }

        completionHandler()
    }

    func deliverNotifications(for messages: [Message]) {
        Task {
            let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
            let deliveredIds = Set(delivered.map { $0.request.identifier })

            for message in messages where !deliveredIds.contains(message.id) {
                let content = UNMutableNotificationContent()
                content.title = message.sender
                content.subtitle = message.subject
                content.body = message.decodedSnippet
                content.userInfo = ["messageId": message.id, "email": message.email]
                content.threadIdentifier = message.email

                let request = UNNotificationRequest(identifier: message.id, content: content, trigger: nil)
                do {
                    try await UNUserNotificationCenter.current().add(request)
                } catch {
                    Log.app.error("Failed to deliver notification for message \(message.id): \(error.localizedDescription)")
                }
            }
        }
    }

    func handleMessagesFetched(email: String, fetcherManager: FetcherManager) {
        guard let account = Accounts.default.find(email: email), account.enabled,
              let fetcher = fetcherManager.fetcher(for: email),
              fetcher.hasNewMessages else { return }

        // Check for VIP senders
        let vipList = VIPList.default
        var playedVIPSound = false

        for message in fetcher.messages {
            if let vipSound = vipList.soundForSender(message.senderEmail) {
                vipSound.nsSound?.play()
                playedVIPSound = true
                break
            }
        }

        // Fall back to account sound
        if !playedVIPSound, let sound = account.sound {
            sound.nsSound?.play()
        }

        guard account.notificationEnabled else { return }

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
                  settings.alertSetting == .enabled else { return }

            deliverNotifications(for: fetcher.messages)
        }
    }
}
