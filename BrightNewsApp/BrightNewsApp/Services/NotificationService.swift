import Foundation
import UserNotifications

/// プッシュ通知管理サービス
/// 「今日の良いニュース」を毎日指定時刻に配信する
final class NotificationService {

    /// シングルトンインスタンス
    static let shared = NotificationService()
    private init() {}

    private let notificationIdentifier = "brightnews-daily"

    // MARK: - Public API

    /// 通知許可をユーザーにリクエスト（初回のみダイアログ表示）
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// 現在の通知許可ステータスを確認
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// 毎日の通知をスケジュール（既存の通知は上書き）
    func scheduleDailyNotification(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()

        // 既存の通知を削除してからスケジュール
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        // 通知コンテンツ
        let content = UNMutableNotificationContent()
        content.title = "☀️ 今日の良いニュース"
        content.body = "今日も心が温まるニュースをお届けします。さっそく読んでみませんか？"
        content.sound = .default
        content.badge = 1

        // 毎日指定時刻に繰り返し
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    /// 通知をキャンセル
    func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }
}
