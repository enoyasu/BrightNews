import Foundation

// MARK: - バックエンドAPI設定
private let kBackendBaseURL = "https://brightnewsbackend-production.up.railway.app"

// MARK: - GNews 設定
// 無料APIキー取得: https://gnews.io/ （無料: 100リクエスト/日）
private let kGNewsAPIKey = "689c5d5a2659169e3e846dd13d0837fd"
private let kGNewsBaseURL = "https://gnews.io/api/v4"

// MARK: - バックエンドAPIレスポンスモデル
// GET /api/v1/articles?category=テクノロジー&limit=50&offset=0

private struct BackendPaginatedResponse: Codable {
    let total:  Int
    let limit:  Int
    let offset: Int
    let items:  [BackendArticleResponse]
}

private struct BackendArticleResponse: Codable {
    let id:         Int
    let title:      String
    let summary:    String
    let category:   String
    let url:        String
    let image_url:  String?
    let created_at: String
}

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

    var errorDescription: String? {
        switch self {
        case .apiKeyNotSet:            return "APIキーが未設定です"
        case .invalidURL:              return "無効なURLです"
        case .networkError(let code):  return "ネットワークエラー (HTTP \(code))"
        }
    }
}

// MARK: - RSSフィード定義

private struct RSSFeed {
    let urlString: String
    let sourceName: String
}

/// カテゴリごとのRSSフィード
/// - NHK: 公共放送（無制限、信頼性高）
/// - ITmedia: 国内テック
/// - Gigazine: テック・サイエンス・エンタメ
/// - Yahoo Japan News: 各ジャンルの最新ニュース
private let kRSSFeeds: [NewsCategory: [RSSFeed]] = [
    .healing: [
        RSSFeed(urlString: "https://www3.nhk.or.jp/rss/news/cat2.xml",           sourceName: "NHK"),
        RSSFeed(urlString: "https://gigazine.net/news/rss_2.0/",                 sourceName: "Gigazine"),
        RSSFeed(urlString: "https://news.yahoo.co.jp/rss/topics/science.xml",    sourceName: "Yahoo!ニュース"),
    ],
    .technology: [
        RSSFeed(urlString: "https://rss.itmedia.co.jp/rss/2.0/itmediamain.xml",  sourceName: "ITmedia"),
        RSSFeed(urlString: "https://gigazine.net/news/rss_2.0/",                 sourceName: "Gigazine"),
        RSSFeed(urlString: "https://www3.nhk.or.jp/rss/news/cat2.xml",           sourceName: "NHK"),
        RSSFeed(urlString: "https://news.yahoo.co.jp/rss/topics/it.xml",         sourceName: "Yahoo!ニュース"),
    ],
    .health: [
        RSSFeed(urlString: "https://www3.nhk.or.jp/rss/news/cat1.xml",           sourceName: "NHK"),
        RSSFeed(urlString: "https://news.yahoo.co.jp/rss/topics/medical.xml",    sourceName: "Yahoo!ニュース"),
    ],
    // goodStory は全般ニュースRSSを使わず GNews 検索クエリのみで厳選取得
    .goodStory: [],
    .entertainment: [
        RSSFeed(urlString: "https://www3.nhk.or.jp/rss/news/cat2.xml",           sourceName: "NHK"),
        RSSFeed(urlString: "https://gigazine.net/news/rss_2.0/",                 sourceName: "Gigazine"),
        RSSFeed(urlString: "https://news.yahoo.co.jp/rss/topics/entertainment.xml", sourceName: "Yahoo!ニュース"),
    ],
    .sports: [
        RSSFeed(urlString: "https://www3.nhk.or.jp/rss/news/cat6.xml",           sourceName: "NHK"),
        RSSFeed(urlString: "https://news.yahoo.co.jp/rss/topics/sports.xml",     sourceName: "Yahoo!ニュース"),
    ],
    .local: [
        RSSFeed(urlString: "https://www3.nhk.or.jp/rss/news/cat7.xml",           sourceName: "NHK"),
        RSSFeed(urlString: "https://www3.nhk.or.jp/rss/news/cat3.xml",           sourceName: "NHK"),
        RSSFeed(urlString: "https://news.yahoo.co.jp/rss/topics/domestic.xml",   sourceName: "Yahoo!ニュース"),
    ],
]

/// ホームフィード用RSS（全ジャンル混合）
private let kHomeRSSFeeds: [RSSFeed] = [
    RSSFeed(urlString: "https://www3.nhk.or.jp/rss/news/cat0.xml",           sourceName: "NHK"),
    RSSFeed(urlString: "https://news.yahoo.co.jp/rss/topics/top-picks.xml",  sourceName: "Yahoo!ニュース"),
]

// MARK: - RSSパーサー（Foundation XMLParser）

private final class RSSParser: NSObject, XMLParserDelegate {

    private let defaultSourceName: String
    private(set) var items: [RSSParsedItem] = []

    // 現在解析中アイテムの一時バッファ
    private var inItem    = false
    private var elemName  = ""
    private var textBuf   = ""
    private var title     = ""
    private var link      = ""
    private var desc      = ""
    private var imageURL  = ""
    private var pubDate   = ""

    private static let rfc2822: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    init(sourceName: String) {
        self.defaultSourceName = sourceName
    }

    func parse(data: Data) -> [RSSParsedItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attrs: [String: String] = [:]) {
        elemName = qName ?? name
        textBuf  = ""

        if name == "item" || name == "entry" {
            inItem   = true
            title    = ""; link = ""; desc = ""; imageURL = ""; pubDate = ""
        }
        guard inItem else { return }

        // 画像URL取得（media:content / media:thumbnail / enclosure）
        let q = qName ?? name
        if (q == "media:content" || q == "media:thumbnail"), imageURL.isEmpty {
            imageURL = attrs["url"] ?? ""
        }
        if q == "enclosure",
           let url  = attrs["url"],
           let type = attrs["type"], type.hasPrefix("image"),
           imageURL.isEmpty {
            imageURL = url
        }
        // Atom <link href="...">
        if name == "link", let href = attrs["href"], link.isEmpty {
            link = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuf += string
    }

    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        if let s = String(data: data, encoding: .utf8) { textBuf += s }
    }

    func parser(_ parser: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard inItem else { return }

        let t = textBuf.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "title":                          if title.isEmpty   { title   = t }
        case "link":                           if link.isEmpty    { link    = t }
        case "description", "summary":         if desc.isEmpty    { desc    = t }
        case "pubDate", "published", "updated": if pubDate.isEmpty { pubDate = t }
        case "item", "entry":
            inItem = false
            guard !title.isEmpty, !link.isEmpty else { return }
            let date = Self.rfc2822.date(from: pubDate)
                    ?? ISO8601DateFormatter().date(from: pubDate)
                    ?? Date()
            items.append(RSSParsedItem(
                title:      title,
                link:       link,
                desc:       desc.strippingHTML(),
                imageURL:   imageURL,
                pubDate:    date,
                sourceName: defaultSourceName
            ))
        default: break
        }
        textBuf = ""
    }
}

private struct RSSParsedItem {
    let title: String
    let link:  String
    let desc:  String
    let imageURL:   String
    let pubDate:    Date
    let sourceName: String
}

// MARK: - String HTML除去ヘルパー

private extension String {
    func strippingHTML() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - ニュース取得サービス

final class NewsService {

    static let shared = NewsService()
    private init() {}

    /// キャッシュ有効期間（1時間）
    private let cacheInterval: TimeInterval = 3600
    /// データ保持期間（30日）
    private let retentionDays: Double = 30

    // MARK: - Public API

    /// ホーム用：バックエンド（優先）+ GNews + RSS を並列取得してマージ
    func fetchAllArticles() async throws -> [Article] {
        let cached = loadCache(forKey: "home")
        if !cached.isEmpty, !cacheExpired(forKey: "home") { return cached }

        var results: [Article] = []

        await withTaskGroup(of: [Article].self) { group in
            // バックエンドAPI（URL設定済みの場合のみ）
            if isBackendConfigured {
                group.addTask { await self.fetchFromBackend(category: nil) }
            }
            // GNews（4カテゴリ）
            let gnewsCategories: [NewsCategory] = [.technology, .entertainment, .sports, .health]
            for cat in gnewsCategories {
                group.addTask { (try? await self.fetchFromGNews(category: cat)) ?? [] }
            }
            // ホーム用RSSフィード
            for feed in kHomeRSSFeeds {
                group.addTask { await self.fetchFromRSS(feed: feed, category: .goodStory) }
            }
            for await articles in group { results.append(contentsOf: articles) }
        }

        guard !results.isEmpty else { throw NewsError.networkError(0) }

        let merged = deduplicated(results).sorted { $0.publishedAt > $1.publishedAt }
        saveCache(merged, forKey: "home")
        return merged
    }

    /// カテゴリ別：バックエンド（優先）+ GNews + RSS をマージ
    func fetchArticles(for category: NewsCategory) async throws -> [Article] {
        let key = category.rawValue
        let cached = loadCache(forKey: key)
        if !cached.isEmpty, !cacheExpired(forKey: key) { return cached }

        var results: [Article] = []

        await withTaskGroup(of: [Article].self) { group in
            // バックエンドAPI（URL設定済みの場合のみ）
            if isBackendConfigured {
                group.addTask { await self.fetchFromBackend(category: category) }
            }
            // GNews API
            group.addTask { (try? await self.fetchFromGNews(category: category)) ?? [] }
            // カテゴリ専用RSSフィード
            for feed in (kRSSFeeds[category] ?? []) {
                group.addTask { await self.fetchFromRSS(feed: feed, category: category) }
            }
            for await articles in group { results.append(contentsOf: articles) }
        }

        let merged = deduplicated(results).sorted { $0.publishedAt > $1.publishedAt }
        saveCache(merged, forKey: key)
        return merged
    }

    /// 追加記事（キャッシュからシャッフル）
    func fetchMoreArticles(page: Int) async throws -> [Article] {
        loadCache(forKey: "home").shuffled()
    }

    // MARK: - Private: バックエンドAPI

    /// kBackendBaseURL が接続可能な状態かチェック
    private var isBackendConfigured: Bool {
        !kBackendBaseURL.contains("YOUR_BACKEND_URL") && !kBackendBaseURL.isEmpty
    }

    /// バックエンド GET /api/v1/articles?category=xxx&limit=50
    /// - category nil → ホーム用（全件取得）
    private func fetchFromBackend(category: NewsCategory?) async -> [Article] {
        var urlStr = "\(kBackendBaseURL)/api/v1/articles?limit=50"
        if let cat = category, let backendCat = backendCategoryName(for: cat) {
            let encoded = backendCat.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? backendCat
            urlStr += "&category=\(encoded)"
        }
        guard let url = URL(string: urlStr) else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

        let paginated = (try? JSONDecoder().decode(BackendPaginatedResponse.self, from: data))
        guard let items = paginated?.items else { return [] }

        return items.compactMap { item in
            guard !item.title.isEmpty, !item.url.isEmpty else { return nil }
            let appCat = category ?? appCategory(from: item.category)
            guard passesFilter(item.title, for: appCat) else { return nil }
            // created_at: "2026-03-28T18:47:49.975749"（タイムゾーンなし）
            let date = Self.backendDateFormatter.date(from: item.created_at)
                    ?? ISO8601DateFormatter().date(from: item.created_at + "Z")
                    ?? Date()
            return Article(
                id:          UUID(),
                title:       item.title,
                summary:     item.summary,
                content:     item.summary,
                imageURL:    item.image_url ?? "",
                sourceURL:   item.url,
                sourceName:  "BrightNews",
                publishedAt: date,
                category:    appCat
            )
        }
    }

    private static let backendDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return f
    }()

    /// アプリカテゴリ → バックエンドカテゴリ名
    private func backendCategoryName(for category: NewsCategory) -> String? {
        switch category {
        case .technology:    return "テクノロジー"
        case .entertainment: return "エンタメ"
        case .health:        return "医療・健康"
        case .healing:       return "癒し"
        case .sports:        return "スポーツ"
        case .local:         return "地域ニュース"
        case .goodStory:     return nil   // goodStory はバックエンドに未対応 → GNews専用
        }
    }

    /// バックエンドカテゴリ名 → アプリカテゴリ（ホームフィード用）
    private func appCategory(from backendCategory: String) -> NewsCategory {
        switch backendCategory {
        case "テクノロジー": return .technology
        case "エンタメ":     return .entertainment
        case "医療・健康":   return .health
        case "癒し":         return .healing
        case "スポーツ":     return .sports
        case "地域ニュース": return .local
        default:             return .local
        }
    }

    // MARK: - Private: GNews

    private func fetchFromGNews(category: NewsCategory) async throws -> [Article] {
        guard kGNewsAPIKey != "YOUR_GNEWS_API_KEY" else { throw NewsError.apiKeyNotSet }
        guard let url = URL(string: gnewsEndpoint(for: category)) else { throw NewsError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NewsError.networkError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(GNewsResponse.self, from: data)
        return decoded.articles.compactMap { convertGNews($0, to: category) }
    }

    private func gnewsEndpoint(for category: NewsCategory) -> String {
        let token  = kGNewsAPIKey
        let max    = 10
        let locale = "lang=ja&country=jp"

        switch category {
        case .healing:
            // 「自然」単体は花粉・災害・警報も拾うため除外。動物・ペット・保護活動に絞る
            let q = "癒し OR ペット OR 保護犬 OR 保護猫 OR 野生動物 OR 動物 OR 自然景観 OR 温泉 OR 絶景"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "healing"
            return "\(kGNewsBaseURL)/search?q=\(q)&\(locale)&max=\(max)&token=\(token)"
        case .technology:
            return "\(kGNewsBaseURL)/top-headlines?category=technology&\(locale)&max=\(max)&token=\(token)"
        case .health:
            return "\(kGNewsBaseURL)/top-headlines?category=health&\(locale)&max=\(max)&token=\(token)"
        case .goodStory:
            // 人助け・善行・感動する話に特化したキーワードで検索
            // 「支援」「増税」など政治・行政系が混入しやすいワードは除外
            let q = "感動 OR 善行 OR ボランティア OR 人助け OR 優しさ OR 笑顔 OR 奇跡 OR 感謝 OR 寄付 OR 助け合い OR 救助 OR 心温まる"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "heartwarming"
            return "\(kGNewsBaseURL)/search?q=\(q)&\(locale)&max=\(max)&token=\(token)"
        case .entertainment:
            return "\(kGNewsBaseURL)/top-headlines?category=entertainment&\(locale)&max=\(max)&token=\(token)"
        case .sports:
            return "\(kGNewsBaseURL)/top-headlines?category=sports&\(locale)&max=\(max)&token=\(token)"
        case .local:
            return "\(kGNewsBaseURL)/top-headlines?category=nation&\(locale)&max=\(max)&token=\(token)"
        }
    }

    private func convertGNews(_ item: GNewsArticle, to category: NewsCategory) -> Article? {
        guard !item.title.isEmpty, !item.url.isEmpty else { return nil }

        // カテゴリ別NGワードフィルター
        if !passesFilter(item.title, for: category) { return nil }

        let date = ISO8601DateFormatter().date(from: item.publishedAt) ?? Date()

        // description: 記事の概要（タイトルと別のテキスト）
        let desc = (item.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = (!desc.isEmpty && desc != item.title) ? desc : item.title

        // content: GNews は末尾に "[N chars]" を付けて截断する → 除去してdescと比較
        let rawContent = (item.content ?? "")
            .replacingOccurrences(of: #"\s*\[\d+ chars\]$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // content が空・title と同一・desc と同一 なら desc を本文とする
        let content: String
        if rawContent.isEmpty || rawContent == item.title || rawContent == desc {
            content = desc.isEmpty ? item.title : desc
        } else {
            content = rawContent
        }

        return Article(
            id:          UUID(),
            title:       item.title,
            summary:     summary,
            content:     content,
            imageURL:    item.image ?? "",
            sourceURL:   item.url,
            sourceName:  item.source.name,
            publishedAt: date,
            category:    category
        )
    }

    // MARK: - Private: カテゴリ別NGワードフィルター

    private func passesFilter(_ title: String, for category: NewsCategory) -> Bool {
        switch category {
        case .goodStory: return passesGoodStoryFilter(title)
        case .healing:   return passesHealingFilter(title)
        default:         return true
        }
    }

    /// 「いい話」: 人助け・善行・感動する話のみ。一つでも混入するとコンセプト崩壊のため厳格に管理。
    private func passesGoodStoryFilter(_ title: String) -> Bool {
        let ngWords: [String] = [
            // 死亡・事件・事故
            "遺体", "死体", "殺人", "殺害", "殺す", "自殺", "自死", "死亡", "行方不明", "失踪",
            "逮捕", "容疑者", "犯罪", "詐欺", "強盗", "窃盗", "暴行", "傷害", "凶器",
            // 紛争・軍事・政治危機
            "戦争", "紛争", "武力", "攻撃", "爆発", "爆撃", "空爆", "ミサイル", "核",
            "情勢", "緊張", "制裁", "侵攻", "占領",
            "イラン", "北朝鮮", "ロシア", "ウクライナ", "パレスチナ", "ガザ",
            // 経済・生活の悪化
            "増税", "値上げ", "物価上昇", "インフレ", "倒産", "リストラ", "閉店", "破綻",
            // 自然災害
            "地震", "津波", "台風", "洪水", "噴火", "土砂崩れ",
            // 感染症・疫病
            "感染拡大", "パンデミック", "新型コロナ",
            // 差別・ハラスメント
            "差別", "ハラスメント", "虐待",
            // 天気・季節（無関係ニュース除外）
            "天気予報", "花見日和", "お花見", "晴れ予報", "花粉", "飛散",
        ]
        return !ngWords.contains { title.contains($0) }
    }

    /// 「癒し」: 動物・自然・ペット・癒し系に特化。花粉・注意報・警報・天気ニュースは除外。
    private func passesHealingFilter(_ title: String) -> Bool {
        let ngWords: [String] = [
            // アレルギー・注意報（癒しと逆効果）
            "花粉", "飛散", "注意報", "警報", "アレルギー", "発令",
            // 天気・季節ニュース（花見日和など）
            "花見", "お花見", "天気予報", "晴れ予報",
            // 自然災害
            "地震", "津波", "台風", "洪水", "噴火", "土砂崩れ",
            // 死亡・事件
            "遺体", "死亡", "殺人", "逮捕", "事故", "衝突",
            // 感染症
            "感染", "ウイルス",
            // 政治・増税
            "増税", "防衛費", "核燃料",
        ]
        return !ngWords.contains { title.contains($0) }
    }

    // MARK: - Private: RSS

    private func fetchFromRSS(feed: RSSFeed, category: NewsCategory) async -> [Article] {
        guard let url = URL(string: feed.urlString) else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }

        let parser = RSSParser(sourceName: feed.sourceName)
        return parser.parse(data: data).compactMap { item in
            guard !item.title.isEmpty, !item.link.isEmpty else { return nil }
            // カテゴリ別NGワードフィルター
            if !passesFilter(item.title, for: category) { return nil }
            // summary: desc が空またはタイトルと同じなら title をそのまま使用
            let summary = (!item.desc.isEmpty && item.desc != item.title) ? item.desc : item.title
            return Article(
                id:          UUID(),
                title:       item.title,
                summary:     summary,
                content:     item.desc.isEmpty ? item.title : item.desc,
                imageURL:    item.imageURL,
                sourceURL:   item.link,
                sourceName:  item.sourceName,
                publishedAt: item.pubDate,
                category:    category
            )
        }
    }

    // MARK: - Public: 記事本文取得（詳細画面で遅延フェッチ）

    /// 記事URLからHTMLを取得し、本文段落を抽出して返す。
    /// 失敗時・ペイウォール等は空文字列を返す（既存のsummary/contentを表示し続ける）。
    func fetchArticleBody(from urlString: String) async -> String {
        // 同一URLの結果はメモリキャッシュで再利用
        if let cached = bodyCache[urlString] { return cached }

        guard let url = URL(string: urlString) else { return "" }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return "" }

        let html = String(data: data, encoding: .utf8)
               ?? String(data: data, encoding: .shiftJIS)
               ?? String(data: data, encoding: .japaneseEUC)
               ?? ""
        guard !html.isEmpty else { return "" }

        // JS必須サイト（SPA）はHTMLだけでは本文が取れないため空文字を返す
        // → ArticleDetailView で article.summary にフォールバックされる
        if isJavaScriptRequiredPage(html) { return "" }

        let body = extractMainContent(from: html)
        if !body.isEmpty { bodyCache[urlString] = body }
        return body
    }

    /// JS が必要な SPA ページかどうかを判定する
    private func isJavaScriptRequiredPage(_ html: String) -> Bool {
        let ngPhrases = [
            "JavaScriptを有効",
            "JavaScript を有効",
            "javascript is not enabled",
            "enable javascript",
            "Enable JavaScript",
            "please enable javascript",
            "requires javascript",
            "This site requires JavaScript",
            "noscript",          // <noscript> のみのページ
            "ブラウザの設定でJavaScript",
            "お使いのブラウザではJavaScript",
        ]
        let lower = html.lowercased()
        // NGフレーズに加え、<p>タグが5個未満かつbody全体が短い場合もSPAと判定
        let hasNGPhrase = ngPhrases.contains { html.contains($0) || lower.contains($0.lowercased()) }
        let isTooShort = html.count < 2000 && !html.contains("</article>")
        return hasNGPhrase || isTooShort
    }

    /// <p> タグ本文抽出。script/style/nav/header/footer を除去してから処理。
    private func extractMainContent(from html: String) -> String {
        // 不要ブロックを先に除去
        var text = html
        for tag in ["script", "style", "nav", "header", "footer", "aside", "figure", "figcaption"] {
            text = text.replacingOccurrences(
                of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>",
                with: "",
                options: .regularExpression
            )
        }

        // <p> タグ本文を抽出
        var paragraphs: [String] = []
        let pattern = "<p[^>]*>([\\s\\S]*?)</p>"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let p = String(text[r])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&amp;",  with: "&")
                    .replacingOccurrences(of: "&lt;",   with: "<")
                    .replacingOccurrences(of: "&gt;",   with: ">")
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .replacingOccurrences(of: "&#39;",  with: "'")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if p.count >= 30 { paragraphs.append(p) }
            }
        }

        // 重複段落を除去し最大20段落
        var seen = Set<String>()
        let unique = paragraphs.filter { seen.insert($0).inserted }
        return unique.prefix(20).joined(separator: "\n\n")
    }

    // 本文のメモリキャッシュ（アプリ起動中のみ有効）
    private var bodyCache: [String: String] = [:]

    // MARK: - Private: 重複排除

    private func deduplicated(_ articles: [Article]) -> [Article] {
        var seen = Set<String>()
        return articles.filter { seen.insert($0.sourceURL).inserted }
    }

    // MARK: - Private: キャッシュ管理

    private func cacheKey(_ k: String)     -> String { "brightnews_cache_\(k)" }
    private func cacheTimeKey(_ k: String) -> String { "brightnews_cache_time_\(k)" }

    func cacheExpired(forKey key: String) -> Bool {
        let last = UserDefaults.standard.object(forKey: cacheTimeKey(key)) as? Date ?? .distantPast
        return Date().timeIntervalSince(last) >= cacheInterval
    }

    private func loadCache(forKey key: String) -> [Article] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(key)) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let all    = (try? decoder.decode([Article].self, from: data)) ?? []
        let cutoff = Date().addingTimeInterval(-retentionDays * 86400)
        return all.filter { $0.publishedAt >= cutoff }
    }

    private func saveCache(_ articles: [Article], forKey key: String) {
        let cutoff = Date().addingTimeInterval(-retentionDays * 86400)
        let valid  = articles.filter { $0.publishedAt >= cutoff }
        let enc    = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(valid) {
            UserDefaults.standard.set(data, forKey: cacheKey(key))
            UserDefaults.standard.set(Date(), forKey: cacheTimeKey(key))
        }
    }
}
