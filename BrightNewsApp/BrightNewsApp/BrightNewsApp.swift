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
        MobileAds.shared.start(completionHandler: nil)
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
                        // ATTダイアログはメイン画面遷移後に表示
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

    private func requestTrackingAuthorization() {
        ATTrackingManager.requestTrackingAuthorization { status in
            print("BrightNews: ATT status = \(status.rawValue)")
        }
    }
}
