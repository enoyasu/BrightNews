import Foundation

// MARK: - GNews 設定
// 無料APIキー取得: https://gnews.io/ （無料: 100リクエスト/日）
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

    /// ホーム用：GNews + RSS を並列取得してマージ
    func fetchAllArticles() async throws -> [Article] {
        let cached = loadCache(forKey: "home")
        if !cached.isEmpty, !cacheExpired(forKey: "home") { return cached }

        var results: [Article] = []

        await withTaskGroup(of: [Article].self) { group in
            // GNews（4カテゴリ）
            let gnewsCategories: [NewsCategory] = [.technology, .entertainment, .sports, .health]
            for cat in gnewsCategories {
                group.addTask { (try? await self.fetchFromGNews(category: cat)) ?? [] }
            }
            // ホーム用RSSフィード
            for feed in kHomeRSSFeeds {
                // ホームのRSS記事は最も近いカテゴリを自動判定
                group.addTask { await self.fetchFromRSS(feed: feed, category: .goodStory) }
            }
            for await articles in group { results.append(contentsOf: articles) }
        }

        guard !results.isEmpty else { throw NewsError.networkError(0) }

        let merged = deduplicated(results).sorted { $0.publishedAt > $1.publishedAt }
        saveCache(merged, forKey: "home")
        return merged
    }

    /// カテゴリ別：GNews + カテゴリ専用RSSをマージ
    func fetchArticles(for category: NewsCategory) async throws -> [Article] {
        let key = category.rawValue
        let cached = loadCache(forKey: key)
        if !cached.isEmpty, !cacheExpired(forKey: key) { return cached }

        var results: [Article] = []

        await withTaskGroup(of: [Article].self) { group in
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
            let q = "動物 OR ペット OR 自然 OR 癒し OR 保護"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "animals"
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

        // goodStory は NGワードフィルターを通過した記事のみ採用
        if category == .goodStory, !passesGoodStoryFilter(item.title) { return nil }

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

    // MARK: - Private: 「いい話」NGワードフィルター
    /// タイトルに以下のキーワードが含まれる記事は「いい話」カテゴリから除外する。
    /// アプリのコンセプト（人助け・善行・感動）を守るための最終防衛ライン。
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
            // 天気・季節（花見日和など無関係ニュースを除外）
            "天気予報", "花見日和", "お花見", "晴れ予報",
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
            // goodStory は NGワードフィルターを通過した記事のみ採用
            if category == .goodStory, !passesGoodStoryFilter(item.title) { return nil }
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
