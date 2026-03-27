import Foundation

/// ニュース記事モデル
/// Codable: UserDefaultsへの保存/読み込みに対応
/// Hashable: SwiftUIのリスト表示に対応
struct Article: Identifiable, Codable, Equatable, Hashable {

    /// 一意の識別子
    let id: UUID

    /// 見出し（タイトル）
    let title: String

    /// 要約（1〜2文、カードに表示）
    let summary: String

    /// 本文（詳細画面に表示）
    let content: String

    /// サムネイル画像のURL文字列
    let imageURL: String

    /// 元記事のURL文字列
    let sourceURL: String

    /// 配信元メディア名
    let sourceName: String

    /// 配信日時
    let publishedAt: Date

    /// カテゴリ
    let category: NewsCategory

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Equatable
    static func == (lhs: Article, rhs: Article) -> Bool {
        lhs.id == rhs.id
    }
}
