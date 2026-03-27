import Foundation
import Combine

/// カテゴリ画面のViewModel
/// カテゴリ選択・絞り込み記事の取得を管理
@MainActor
final class CategoryViewModel: ObservableObject {

    // MARK: - Published Properties

    /// フィルタリングされた記事一覧
    @Published var articles: [Article] = []

    /// 読み込み中フラグ
    @Published var isLoading: Bool = false

    /// 現在選択中のカテゴリ
    @Published var selectedCategory: NewsCategory? = nil

    /// エラーメッセージ
    @Published var errorMessage: String? = nil

    // MARK: - Private

    private let newsService = NewsService.shared

    // MARK: - Public Methods

    /// 指定カテゴリの記事を読み込む
    func loadArticles(for category: NewsCategory) async {
        // 同じカテゴリを再選択した場合は読み込みをスキップ
        if selectedCategory == category && !articles.isEmpty { return }

        isLoading = true
        selectedCategory = category
        errorMessage = nil

        do {
            articles = try await newsService.fetchArticles(for: category)
        } catch {
            errorMessage = "記事の読み込みに失敗しました。"
            articles = []
        }

        isLoading = false
    }
}
