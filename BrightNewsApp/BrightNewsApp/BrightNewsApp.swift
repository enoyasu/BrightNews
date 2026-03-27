import SwiftUI
import GoogleMobileAds          // AdMob SDK v13+
import AppTrackingTransparency  // iOS 14+ 広告トラッキング許可

/// BrightNews アプリのエントリーポイント
@main
struct BrightNewsApp: App {

    @StateObject private var favoritesService = FavoritesService()
    @StateObject private var appSettings     = AppSettings()
    @StateObject private var purchaseService = PurchaseService()

    init() {
        // AdMob SDK 初期化（v13+ の正式な呼び出し形式）
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(favoritesService)
                .environmentObject(appSettings)
                .environmentObject(purchaseService)
                .onAppear {
                    // 起動から1秒後に ATT 許可ダイアログを表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        requestTrackingAuthorization()
                    }
                }
        }
    }

    /// App Tracking Transparency 許可リクエスト
    private func requestTrackingAuthorization() {
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:  print("BrightNews: 広告トラッキング許可")
            case .denied:      print("BrightNews: 広告トラッキング拒否 → 非パーソナライズ広告")
            default:           break
            }
        }
    }
}
