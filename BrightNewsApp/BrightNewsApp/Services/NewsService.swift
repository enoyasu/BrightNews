import Foundation

/// ニュース取得サービス
/// 現在はダミーデータを使用。本番では NewsAPI などを呼び出す
final class NewsService {

    /// シングルトンインスタンス
    static let shared = NewsService()
    private init() {}

    // MARK: - Public API

    /// ホーム用：全カテゴリの記事を取得（シャッフル済み）
    func fetchAllArticles() async throws -> [Article] {
        // 本番APIに差し替える場合はここを変更する
        // 例: let (data, _) = try await URLSession.shared.data(from: apiURL)
        try await simulateNetworkDelay(0.8)
        return DummyData.articles.shuffled()
    }

    /// カテゴリ別記事を取得
    func fetchArticles(for category: NewsCategory) async throws -> [Article] {
        try await simulateNetworkDelay(0.5)
        return DummyData.articles.filter { $0.category == category }
    }

    /// 追加記事の取得（無限スクロール用）
    func fetchMoreArticles(page: Int) async throws -> [Article] {
        try await simulateNetworkDelay(0.6)
        // ダミーデータはシャッフルして再利用
        return DummyData.articles.shuffled()
    }

    // MARK: - Private

    /// ネットワーク遅延のシミュレーション（秒単位）
    private func simulateNetworkDelay(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
