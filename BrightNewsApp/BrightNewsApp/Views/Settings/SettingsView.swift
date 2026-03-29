import SwiftUI
import UserNotifications

/// 設定画面
/// 通知・文字サイズ・アプリ情報の設定
struct SettingsView: View {

    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var purchaseService: PurchaseService
    @StateObject private var viewModel = SettingsViewModel()

    @State private var showPremium = false

    private let privacyPolicyURL = URL(string: "https://novelostudio.github.io/legal/brightnews/privacy_policy.html")
    private let termsOfServiceURL = URL(string: "https://novelostudio.github.io/legal/brightnews/terms_of_service.html")
    private let appStoreDeveloperURL = URL(string: "https://apps.apple.com/jp/developer/brightnews")

    // 通知時刻の一時保存（DatePicker用）
    @State private var notificationTime: Date = {
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    var body: some View {
        List {

            // MARK: プレミアム
            Section {
                if purchaseService.isPremium {
                    // プレミアム会員バッジ
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("プレミアム会員")
                                .font(.body.weight(.semibold))
                            Text("広告なしでご利用いただけます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } else {
                    // プレミアム誘導バナー
                    Button {
                        showPremium = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.brightPrimary, Color.yellow.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.white)
                                    .font(.footnote)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("広告を非表示にする")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text("月額¥250〜 広告ゼロで快適に")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showPremium) {
                PremiumView()
                    .environmentObject(purchaseService)
            }

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
                    Text("Novelo Studio")
                        .foregroundColor(.secondary)
                }

                if let privacyPolicyURL {
                    Link(destination: privacyPolicyURL) {
                        Label("プライバシーポリシー", systemImage: "lock.shield.fill")
                    }
                }

                if let termsOfServiceURL {
                    Link(destination: termsOfServiceURL) {
                        Label("利用規約", systemImage: "doc.text.fill")
                    }
                }

                // TODO: App Store公開後にAppIDを含む正式URLへ変更してください
                // 例: https://apps.apple.com/jp/app/brightnews/id000000000
                if let appStoreDeveloperURL {
                    Link(destination: appStoreDeveloperURL) {
                        Label("App Storeでレビューする", systemImage: "star.fill")
                    }
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
