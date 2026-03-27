import SwiftUI

/// BrightNews アプリのエントリーポイント
/// 明るいニュースのみを厳選してお届けする、ポジティブニュースアプリ
@main
struct BrightNewsApp: App {

    // アプリ全体で共有するEnvironmentObject
    @StateObject private var favoritesService = FavoritesService()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var purchaseService = PurchaseService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(favoritesService)
                .environmentObject(appSettings)
                .environmentObject(purchaseService)
        }
    }
}
