import Foundation

// MARK: - GNews 設定
// 無料APIキーの取得: https://gnews.io/ でアカウント作成（無料: 100リクエスト/日）
// 本番リリース前にキーを設定してください
private let kGNewsAPIKey = "689c5d5a2659169e3e846dd13d0837fd"
private let kGNewsBaseURL = "https://gnews.io/api/v4"

// MARK: - GNews APIレスポンスモデル

private struct GNewsResponse: Codable {
    let totalArticles: Int
    let articles: [GNewsArticle]
}

private struct GNewsArticle: Codable {
    let title: String
    let description: String?
    let content: String?
    let url: String
    let image: String?
    let publishedAt: String
    let source: GNewsSource
}

private struct GNewsSource: Codable {
    let name: String
    let url: String
}

// MARK: - エラー定義

enum NewsError: LocalizedError {
    case apiKeyNotSet
    case invalidURL
    case networkError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .apiKeyNotSet:    return "APIキーが設定されていません。NewsService.swift の kGNewsAPIKey を設定してください"
        case .invalidURL:      return "無効なURLです"
        case .networkError(let code): return "ネットワークエラー (HTTP \(code))"
        case .decodingError:   return "データの解析に失敗しました"
        }
    }
}

// MARK: - ニュース取得サービス

final class NewsService {

    static let shared = NewsService()
    private init() {}

    /// キャッシュ保持期間（秒）: 1時間
    private let cacheInterval: TimeInterval = 3600
    /// データ保持期間（日）: 30日
    private let retentionDays: Double = 30

    // MARK: - Public API

    /// ホーム用：複数カテゴリをまとめて取得（キャッシュ対応）
    func fetchAllArticles() async throws -> [Article] {
        let cached = loadCache(forKey: "home")
        if !cached.isEmpty, !cacheExpired(forKey: "home") {
            return cached
        }

        let homeCategories: [NewsCategory] = [.technology, .entertainment, .sports, .health]
        var results: [Article] = []

        await withTaskGroup(of: [Article].self) { group in
            for category in homeCategories {
                group.addTask { (try? await self.fetchFromAPI(category: category)) ?? [] }
            }
            for await articles in group {
                results.append(contentsOf: articles)
            }
        }

        guard !results.isEmpty else { throw NewsError.networkError(0) }

        let sorted = results.sorted { $0.publishedAt > $1.publishedAt }
        saveCache(sorted, forKey: "home")
        return sorted
    }

    /// カテゴリ別記事を取得（キャッシュ対応）
    func fetchArticles(for category: NewsCategory) async throws -> [Article] {
        let key = category.rawValue
        let cached = loadCache(forKey: key)
        if !cached.isEmpty, !cacheExpired(forKey: key) {
            return cached
        }

        let articles = try await fetchFromAPI(category: category)
        saveCache(articles, forKey: key)
        return articles
    }

    /// 追加記事の取得（キャッシュからシャッフルして返す）
    func fetchMoreArticles(page: Int) async throws -> [Article] {
        return loadCache(forKey: "home").shuffled()
    }

    // MARK: - Private: GNews API呼び出し

    private func fetchFromAPI(category: NewsCategory) async throws -> [Article] {
        guard kGNewsAPIKey != "YOUR_GNEWS_API_KEY" else {
            throw NewsError.apiKeyNotSet
        }

        guard let url = URL(string: endpoint(for: category)) else {
            throw NewsError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NewsError.networkError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(GNewsResponse.self, from: data)
        return decoded.articles.compactMap { convert($0, to: category) }
    }

    /// カテゴリ→GNews APIエンドポイントのマッピング（日本語記事のみ）
    private func endpoint(for category: NewsCategory) -> String {
        let token = kGNewsAPIKey
        let max = 10
        let locale = "lang=ja&country=jp"

        switch category {
        case .healing:
            let q = "動物 OR ペット OR 自然 OR 癒し OR 保護"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "%E5%8B%95%E7%89%A9"
            return "\(kGNewsBaseURL)/search?q=\(q)&\(locale)&max=\(max)&token=\(token)"
        case .technology:
            return "\(kGNewsBaseURL)/top-headlines?category=technology&\(locale)&max=\(max)&token=\(token)"
        case .health:
            return "\(kGNewsBaseURL)/top-headlines?category=health&\(locale)&max=\(max)&token=\(token)"
        case .goodStory:
            let q = "ボランティア OR 感動 OR 善行 OR 支援 OR 親切"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "%E6%84%9F%E5%8B%95"
            return "\(kGNewsBaseURL)/search?q=\(q)&\(locale)&max=\(max)&token=\(token)"
        case .entertainment:
            return "\(kGNewsBaseURL)/top-headlines?category=entertainment&\(locale)&max=\(max)&token=\(token)"
        case .sports:
            return "\(kGNewsBaseURL)/top-headlines?category=sports&\(locale)&max=\(max)&token=\(token)"
        case .local:
            return "\(kGNewsBaseURL)/top-headlines?category=nation&\(locale)&max=\(max)&token=\(token)"
        }
    }

    /// GNewsArticle → Articleモデルへの変換
    private func convert(_ item: GNewsArticle, to category: NewsCategory) -> Article? {
        guard !item.title.isEmpty, !item.url.isEmpty else { return nil }

        let date = ISO8601DateFormatter().date(from: item.publishedAt) ?? Date()

        // GNews無料枠はcontentを "[N chars]" で打ち切る → 除去
        let rawContent = item.content ?? item.description ?? ""
        let cleanContent = rawContent.replacingOccurrences(
            of: #" \[\d+ chars\]$"#,
            with: "",
            options: .regularExpression
        )
        let body = cleanContent.isEmpty ? (item.description ?? "") : cleanContent

        return Article(
            id: UUID(),
            title: item.title,
            summary: item.description ?? item.title,
            content: body,
            imageURL: item.image ?? "",
            sourceURL: item.url,
            sourceName: item.source.name,
            publishedAt: date,
            category: category
        )
    }

    // MARK: - Private: キャッシュ管理

    private func cacheKey(_ key: String)      -> String { "brightnews_cache_\(key)" }
    private func cacheTimeKey(_ key: String)  -> String { "brightnews_cache_time_\(key)" }

    /// キャッシュが期限切れかどうか（1時間）
    func cacheExpired(forKey key: String) -> Bool {
        let last = UserDefaults.standard.object(forKey: cacheTimeKey(key)) as? Date ?? .distantPast
        return Date().timeIntervalSince(last) >= cacheInterval
    }

    /// キャッシュ読み込み（30日以内のみ返す）
    private func loadCache(forKey key: String) -> [Article] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(key)) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let all = (try? decoder.decode([Article].self, from: data)) ?? []
        let cutoff = Date().addingTimeInterval(-retentionDays * 86400)
        return all.filter { $0.publishedAt >= cutoff }
    }

    /// キャッシュ書き込み（30日以内のデータのみ保存）
    private func saveCache(_ articles: [Article], forKey key: String) {
        let cutoff = Date().addingTimeInterval(-retentionDays * 86400)
        let valid = articles.filter { $0.publishedAt >= cutoff }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(valid) {
            UserDefaults.standard.set(data, forKey: cacheKey(key))
            UserDefaults.standard.set(Date(), forKey: cacheTimeKey(key))
        }
    }
}
