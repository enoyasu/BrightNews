import Foundation

/// ホーム・カテゴリフィードの要素
/// 記事カードとネイティブ広告カードを同列に扱うための型
enum FeedItem: Identifiable {

    /// 通常の記事カード
    case article(Article)

    /// ネイティブ広告カード（各IDはユニークなUUID）
    case nativeAd(id: UUID)

    // Identifiable 準拠
    var id: String {
        switch self {
        case .article(let article):   return "article_\(article.id)"
        case .nativeAd(let uuid):     return "ad_\(uuid.uuidString)"
        }
    }
}
