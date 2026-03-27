import SwiftUI

/// ニュースカテゴリ定義
/// 明るいニュースのみを扱う7カテゴリ
enum NewsCategory: String, CaseIterable, Codable, Identifiable {

    case healing       = "healing"       // 癒し（動物・自然）
    case technology    = "technology"    // テクノロジー
    case health        = "health"        // 医療・健康
    case goodStory     = "goodStory"     // いい話
    case entertainment = "entertainment" // エンタメ
    case sports        = "sports"        // スポーツ
    case local         = "local"         // 地域ニュース

    var id: String { rawValue }

    // MARK: - 表示名（日本語）
    var displayName: String {
        switch self {
        case .healing:       return "癒し"
        case .technology:    return "テクノロジー"
        case .health:        return "医療・健康"
        case .goodStory:     return "いい話"
        case .entertainment: return "エンタメ"
        case .sports:        return "スポーツ"
        case .local:         return "地域ニュース"
        }
    }

    // MARK: - SF Symbolsアイコン名
    var icon: String {
        switch self {
        case .healing:       return "leaf.fill"
        case .technology:    return "cpu.fill"
        case .health:        return "heart.fill"
        case .goodStory:     return "hands.clap.fill"
        case .entertainment: return "star.fill"
        case .sports:        return "figure.run"
        case .local:         return "map.fill"
        }
    }

    // MARK: - カテゴリ別アクセントカラー
    var color: Color {
        switch self {
        case .healing:
            return Color(red: 0.25, green: 0.72, blue: 0.45)  // グリーン
        case .technology:
            return Color(red: 0.20, green: 0.48, blue: 0.88)  // ブルー
        case .health:
            return Color(red: 0.92, green: 0.30, blue: 0.45)  // ピンク
        case .goodStory:
            return Color(red: 1.00, green: 0.62, blue: 0.10)  // オレンジ
        case .entertainment:
            return Color(red: 0.58, green: 0.28, blue: 0.88)  // パープル
        case .sports:
            return Color(red: 0.95, green: 0.42, blue: 0.18)  // レッドオレンジ
        case .local:
            return Color(red: 0.08, green: 0.68, blue: 0.68)  // ティール
        }
    }

    // MARK: - カテゴリ説明文（設定画面などで使用）
    var description: String {
        switch self {
        case .healing:       return "動物・自然の癒しニュース"
        case .technology:    return "テクノロジーの進歩・発明"
        case .health:        return "医療の成功例・健康情報"
        case .goodStory:     return "人助け・善行・感動の話"
        case .entertainment: return "文化・エンタメの明るい話"
        case .sports:        return "スポーツの感動・活躍"
        case .local:         return "地域の良い取り組み"
        }
    }
}
