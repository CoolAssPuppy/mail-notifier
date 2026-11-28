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

    /// The last permission state read from macOS. The classic menu is built
    /// synchronously and reads this; it is refreshed at launch, whenever a
    /// menu opens, and after a request.
    private(set) var lastKnownPermission: NotificationPermission = .notDetermined
    private var authorizationRequest: Task<NotificationPermission, Never>?

    /// Takes over notification clicks. Does not ask for permission: that
    /// waits until an account exists, so the prompt arrives when the person
    /// can see why the app wants it.
    @MainActor
    func setup() {
        UNUserNotificationCenter.current().delegate = self
        // Installs that already have accounts but never answered the prompt.
        if Accounts.hasAccounts {
            Task { _ = await requestAuthorizationIfNeeded() }
        }
    }

    /// Reads the current permission and remembers it.
    @MainActor
    @discardableResult
    func refreshPermission() async -> NotificationPermission {
        let permission = await NotificationPermission.current()
        lastKnownPermission = permission
        return permission
    }

    /// Asks macOS for permission once, if the person has not answered yet.
    /// Concurrent callers share the one request, so the prompt never stacks.
    @MainActor
    func requestAuthorizationIfNeeded() async -> NotificationPermission {
        if let authorizationRequest { return await authorizationRequest.value }
        let request = Task { @MainActor () -> NotificationPermission in
            let current = await refreshPermission()
            guard current == .notDetermined else { return current }
            do {
                // .sound is required now that the notification carries the
                // sound. Without it the system shows the banner but stays silent.
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            } catch {
                Log.app.error("Failed to request notification authorization: \(error.localizedDescription, privacy: .public)")
            }
            let answered = await refreshPermission()
            if answered.isBlocked {
                Log.app.info("Notifications were declined; the menu will say so")
            }
            NotificationCenter.default.post(name: .notificationPermissionChanged, object: nil)
            return answered
        }
        authorizationRequest = request
        let result = await request.value
        authorizationRequest = nil
        return result
    }

    /// The one notification after a new account's first check, so the person
    /// knows the connection works even when the inbox is empty.
    func deliverConnectedNotice(for account: Account, unreadCount: Int) {
        guard account.notificationEnabled else { return }
        Task { @MainActor in
            let permission = await requestAuthorizationIfNeeded()
            guard permission == .granted || permission == .provisional else {
                Log.app.info("Skipped the connected notification: notifications are not allowed")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = ConnectedNotice.title(unreadCount: unreadCount)
            content.body = account.displayName
            content.threadIdentifier = account.email
            let request = UNNotificationRequest(identifier: "connected:\(account.type.rawValue):\(account.email.lowercased())",
                                                content: content, trigger: nil)
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                Log.app.error("Failed to deliver the connected notification: \(error.localizedDescription, privacy: .public)")
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

    func deliverNotifications(for messages: [Message], account: Account, isDemo: Bool) {
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
                guard isDemo == DemoMode.isOnNow else { return }
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
                  settings.alertSetting == .enabled else {
                // Not silent any more: the menu shows a line with a way to
                // turn notifications back on.
                Log.app.info("New mail not shown: notifications are not allowed (status \(settings.authorizationStatus.rawValue, privacy: .public))")
                return
            }

            // The sound rides on the notification (see deliverNotifications) so
            // macOS plays it and Focus governs it. We no longer play it directly
            // with NSSound, which bypassed Focus entirely.
            deliverNotifications(for: fetcher.messages, account: account, isDemo: fetcher.isDemo)
        }
    }
}
