import Foundation
import Combine

/// お気に入り記事の管理サービス
/// UserDefaults に Codable でシリアライズして永続化
final class FavoritesService: ObservableObject {

    /// お気に入り記事一覧（変更時にUI自動更新）
    @Published private(set) var favorites: [Article] = []

    private let storageKey = "brightnews_saved_favorites"

    init() {
        loadFavorites()
    }

    // MARK: - Public API

    /// 指定記事がお気に入りに含まれているか確認
    func isFavorite(_ article: Article) -> Bool {
        favorites.contains { $0.id == article.id }
    }

    /// お気に入りの追加・削除を切り替え
    func toggleFavorite(_ article: Article) {
        if isFavorite(article) {
            favorites.removeAll { $0.id == article.id }
        } else {
            favorites.insert(article, at: 0) // 最新を先頭に追加
        }
        saveFavorites()
    }

    // MARK: - Private

    /// お気に入りを UserDefaults に保存
    private func saveFavorites() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    /// UserDefaults からお気に入りを読み込み
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([Article].self, from: data) {
            favorites = decoded
        }
    }
}
