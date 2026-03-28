import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

/// BrightNews アプリのエントリーポイント
@main
struct BrightNewsApp: App {

    @StateObject private var favoritesService = FavoritesService()
    @StateObject private var appSettings     = AppSettings()
    @StateObject private var purchaseService = PurchaseService()

    /// 起動アニメーション表示中かどうか
    @State private var isLaunching = true

    init() {
        // AdMob の start は ATT 許可ダイアログ応答後に実行（下記参照）
        // Apple ガイドライン: IDFA アクセス前に ATT を取得すること
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLaunching {
                    // ── 起動アニメーション画面 ──
                    LaunchScreenView {
                        withAnimation(.easeOut(duration: 0.4)) {
                            isLaunching = false
                        }
                        // メイン画面に切り替わった直後に ATT ダイアログを表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            requestTrackingAuthorization()
                        }
                    }
                    .transition(.opacity)
                } else {
                    // ── メインタブ画面 ──
                    MainTabView()
                        .environmentObject(favoritesService)
                        .environmentObject(appSettings)
                        .environmentObject(purchaseService)
                        .transition(.opacity)
                }
            }
        }
    }

    /// ATT 許可ダイアログを表示し、応答後に AdMob を起動する。
    /// - 許可・拒否どちらでも AdMob は起動（拒否時は非パーソナライズ広告で動作）
    /// - iOS 14 未満は ATT 不要のため直接 AdMob を起動
    private func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    // ステータスに関わらず AdMob 起動（非パーソナライズ広告にも対応）
                    MobileAds.shared.start(completionHandler: nil)
                    #if DEBUG
                    print("BrightNews ATT status: \(status.rawValue)")
                    #endif
                }
            }
        } else {
            MobileAds.shared.start(completionHandler: nil)
        }
    }
}
