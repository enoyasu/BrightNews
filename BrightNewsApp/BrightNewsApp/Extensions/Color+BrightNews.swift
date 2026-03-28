import SwiftUI
import UIKit

/// BrightNewsアプリ専用カラーパレット拡張
extension Color {

    /// プライマリカラー：温かみのあるサンシャインオレンジ
    static let brightPrimary = Color(red: 1.0, green: 0.58, blue: 0.18)

    /// アプリ背景色：ライト=ソフトクリーム / ダーク=システム背景（自動対応）
    static var brightBackground: Color {
        Color(UIColor(dynamicProvider: { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.systemBackground
                : UIColor(red: 0.97, green: 0.95, blue: 0.93, alpha: 1)
        }))
    }

    /// カード背景色：システム背景（ダークモード自動対応）
    static var brightCard: Color { Color(.systemBackground) }

    /// アクセントカラー：さわやかなスカイブルー
    static let brightAccent = Color(red: 0.20, green: 0.53, blue: 0.92)

    /// グラデーション開始色（バナー用）
    static let brightGradientStart = Color(red: 1.0, green: 0.75, blue: 0.30)

    /// グラデーション終了色（バナー用）
    static let brightGradientEnd = Color(red: 1.0, green: 0.52, blue: 0.15)
}
