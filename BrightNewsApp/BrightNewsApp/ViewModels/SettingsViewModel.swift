import Foundation
import Combine
import UserNotifications

/// 設定画面のViewModel
/// 通知許可状態の確認・スケジューリングを管理
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// 現在の通知許可ステータス
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Public Methods

    /// 通知許可ステータスを確認（画面表示時に呼ぶ）
    func checkNotificationStatus() async {
        notificationStatus = await NotificationService.shared.checkPermissionStatus()
    }

    /// 通知許可をリクエスト（ユーザーにダイアログ表示）
    func requestNotificationPermission() async {
        await NotificationService.shared.requestPermission()
        await checkNotificationStatus()
    }

    /// 指定時刻に毎日通知をスケジュール
    func scheduleNotification(hour: Int, minute: Int) {
        NotificationService.shared.scheduleDailyNotification(hour: hour, minute: minute)
    }

    /// 通知をキャンセル
    func cancelNotification() {
        NotificationService.shared.cancelNotification()
    }

    /// 通知が許可されているか（設定アプリで拒否された場合も考慮）
    var isNotificationAuthorized: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional
    }
}
