import SwiftUI

/// アプリのルートビュー
/// 3タブ（ホーム・カテゴリ・設定）を管理
struct MainTabView: View {

    @EnvironmentObject var favoritesService: FavoritesService
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        TabView {
            // MARK: ① ホームタブ
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("ホーム", systemImage: "sun.max.fill")
            }

            // MARK: ② カテゴリタブ
            NavigationStack {
                CategoryView()
            }
            .tabItem {
                Label("カテゴリ", systemImage: "square.grid.2x2.fill")
            }

            // MARK: ③ 設定タブ
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape.fill")
            }
        }
        .tint(Color.brightPrimary)
    }
}
