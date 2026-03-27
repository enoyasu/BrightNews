import SwiftUI
import UserNotifications

/// 設定画面
/// 通知・文字サイズ・アプリ情報の設定
struct SettingsView: View {

    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var viewModel = SettingsViewModel()

    // 通知時刻の一時保存（DatePicker用）
    @State private var notificationTime: Date = {
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    var body: some View {
        List {

            // MARK: お気に入り
            Section {
                NavigationLink(destination: FavoritesView()) {
                    Label {
                        Text("お気に入り記事")
                    } icon: {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(Color.brightPrimary)
                    }
                }
            }

            // MARK: 通知設定
            Section("通知設定") {
                // 通知ON/OFFトグル
                Toggle(isOn: $appSettings.notificationsEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("今日の良いニュース通知")
                            Text("毎日1回お届けします")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                    }
                }
                .tint(Color.brightPrimary)
                .onChange(of: appSettings.notificationsEnabled) { _, enabled in
                    handleNotificationToggle(enabled)
                }

                // 通知許可が拒否されている場合の警告
                if !viewModel.isNotificationAuthorized && viewModel.notificationStatus == .denied {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                        Text("設定アプリから通知を許可してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("設定を開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.brightPrimary)
                    }
                }

                // 通知時刻のDatePicker
                if appSettings.notificationsEnabled {
                    DatePicker(
                        "通知時刻",
                        selection: $notificationTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: notificationTime) { _, newTime in
                        let calendar = Calendar.current
                        appSettings.notificationHour = calendar.component(.hour, from: newTime)
                        appSettings.notificationMinute = calendar.component(.minute, from: newTime)
                        viewModel.scheduleNotification(
                            hour: appSettings.notificationHour,
                            minute: appSettings.notificationMinute
                        )
                    }
                }
            }

            // MARK: 表示設定
            Section("表示設定") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("文字サイズ", systemImage: "textformat.size")
                        .font(.body)

                    Picker("文字サイズ", selection: Binding(
                        get: { appSettings.fontSize },
                        set: { appSettings.fontSize = $0 }
                    )) {
                        ForEach(FontSize.allCases, id: \.rawValue) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)

                    // プレビューテキスト
                    Text("サンプルテキスト：今日も明るいニュースをお届けします。")
                        .font(.system(size: appSettings.fontSize.bodySize))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // MARK: アプリについて
            Section("アプリについて") {
                HStack {
                    Label("バージョン", systemImage: "info.circle.fill")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("開発者", systemImage: "person.fill")
                    Spacer()
                    Text("BrightNews Team")
                        .foregroundColor(.secondary)
                }

                // TODO: 公開後に実際のURLへ変更してください
                Link(destination: URL(string: "https://your-domain.com/privacy")!) {
                    Label("プライバシーポリシー", systemImage: "lock.shield.fill")
                }

                // TODO: 公開後に実際のURLへ変更してください
                Link(destination: URL(string: "https://your-domain.com/terms")!) {
                    Label("利用規約", systemImage: "doc.text.fill")
                }

                // TODO: App Store公開後にAppIDを含む正式URLへ変更してください
                // 例: https://apps.apple.com/jp/app/brightnews/id000000000
                Link(destination: URL(string: "https://apps.apple.com/jp/developer/brightnews")!) {
                    Label("App Storeでレビューする", systemImage: "star.fill")
                }
            }

            // MARK: ブランドフッター
            Section {
                VStack(spacing: 6) {
                    Text("☀️ BrightNews")
                        .font(.headline)
                        .foregroundColor(Color.brightPrimary)
                    Text("明るいニュースで、毎日を笑顔に。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("設定")
        .task {
            await viewModel.checkNotificationStatus()
            // 保存済みの通知時刻を DatePicker に反映
            restoreNotificationTime()
        }
    }

    // MARK: - Private Helpers

    /// 通知トグル変更時の処理
    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            Task {
                await viewModel.requestNotificationPermission()
                if viewModel.isNotificationAuthorized {
                    viewModel.scheduleNotification(
                        hour: appSettings.notificationHour,
                        minute: appSettings.notificationMinute
                    )
                }
            }
        } else {
            viewModel.cancelNotification()
        }
    }

    /// 保存された通知時刻を DatePicker に反映
    private func restoreNotificationTime() {
        var components = DateComponents()
        components.hour = appSettings.notificationHour
        components.minute = appSettings.notificationMinute
        if let date = Calendar.current.date(from: components) {
            notificationTime = date
        }
    }
}
