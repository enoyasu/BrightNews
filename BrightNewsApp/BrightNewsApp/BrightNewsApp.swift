import SwiftUI
import GoogleMobileAds          // AdMob SDK（SPM追加後に有効）
import AppTrackingTransparency  // iOS 14+ 広告トラッキング許可ダイアログ

/// BrightNews アプリのエントリーポイント
/// 明るいニュースのみを厳選してお届けする、ポジティブニュースアプリ
@main
struct BrightNewsApp: App {

    // MARK: - EnvironmentObjects

    @StateObject private var favoritesService = FavoritesService()
    @StateObject private var appSettings     = AppSettings()
    @StateObject private var purchaseService = PurchaseService()

    // MARK: - Init（AdMob SDK 初期化）

    init() {
        // AdMob SDK を起動（アプリ起動と同時に初期化が必要）
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(favoritesService)
                .environmentObject(appSettings)
                .environmentObject(purchaseService)
                .onAppear {
                    // 起動から1秒後にATT（広告トラッキング許可）ダイアログを表示
                    // 即時表示するとユーザー体験が悪いため少し遅延させる
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        requestTrackingAuthorization()
                    }
                }
        }
    }

    // MARK: - ATT 許可リクエスト

    /// App Tracking Transparency 許可ダイアログを表示
    /// 許可した場合：パーソナライズ広告が表示され収益が最大化される
    /// 拒否した場合：非パーソナライズ広告が表示される（アプリは正常に動作）
    private func requestTrackingAuthorization() {
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:
                print("BrightNews: 広告トラッキング許可")
            case .denied, .restricted:
                print("BrightNews: 広告トラッキング拒否 → 非パーソナライズ広告で運用")
            case .notDetermined:
                print("BrightNews: 広告トラッキング未決定")
            @unknown default:
                break
            }
        }
    }
}
