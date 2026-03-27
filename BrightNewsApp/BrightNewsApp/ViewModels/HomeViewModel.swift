import Foundation
import Combine

/// ホーム画面のViewModel
/// 記事一覧の取得・無限スクロール・プルリフレッシュを管理
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties

    /// 表示中の記事一覧（生データ）
    @Published var articles: [Article] = []

    /// 広告を含むフィードアイテム（HomeViewで使用）
    @Published var feedItems: [FeedItem] = []

    /// 初回読み込み中フラグ
    @Published var isLoading: Bool = false

    /// 追加読み込み中フラグ（フッターインジケーター用）
    @Published var isLoadingMore: Bool = false

    /// エラーメッセージ（nilの場合はエラーなし）
    @Published var errorMessage: String? = nil

    /// 追加読み込みが可能かどうか
    @Published var hasMore: Bool = true

    // MARK: - Private

    private var currentPage: Int = 0
    private let maxPages: Int = 3
    private let newsService = NewsService.shared

    // MARK: - Public Methods

    /// 初回記事読み込み
    func loadArticles(isPremium: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        currentPage = 0

        do {
            articles = try await newsService.fetchAllArticles()
            hasMore = true
            buildFeed(isPremium: isPremium)
        } catch {
            errorMessage = "ニュースの読み込みに失敗しました。\n通信状態をご確認ください。"
        }

        isLoading = false
    }

    /// 追加記事の読み込み（無限スクロール）
    func loadMoreArticles(isPremium: Bool = false) async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        currentPage += 1

        do {
            let moreArticles = try await newsService.fetchMoreArticles(page: currentPage)
            articles.append(contentsOf: moreArticles)
            hasMore = currentPage < maxPages
            buildFeed(isPremium: isPremium)
        } catch {
            // 追加読み込みエラーは静かに無視（UX向上のため）
        }

        isLoadingMore = false
    }

    /// プルして更新
    func refresh(isPremium: Bool = false) async {
        await loadArticles(isPremium: isPremium)
    }

    // MARK: - Private

    /// 記事リストから広告入りフィードを構築する
    /// - プレミアムユーザー: 広告なし
    /// - 無料ユーザー: AdConfig.adInterval 記事ごとに広告1枚を挿入
    private func buildFeed(isPremium: Bool) {
        var items: [FeedItem] = []
        for (index, article) in articles.enumerated() {
            items.append(.article(article))
            // プレミアムでない場合のみ広告を挿入
            if !isPremium && (index + 1) % AdConfig.adInterval == 0 {
                items.append(.nativeAd(id: UUID()))
            }
        }
        feedItems = items
    }
}
