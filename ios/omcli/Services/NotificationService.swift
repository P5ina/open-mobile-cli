import UserNotifications

final class NotificationService {
    var isAuthorized: Bool {
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            result = settings.authorizationStatus == .authorized
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func send(title: String, body: String, priority: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = priority == "critical" ? .defaultCritical : .default
        if priority == "critical" {
            content.interruptionLevel = .critical
        } else if priority == "low" {
            content.interruptionLevel = .passive
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        try await UNUserNotificationCenter.current().add(request)
    }
}
