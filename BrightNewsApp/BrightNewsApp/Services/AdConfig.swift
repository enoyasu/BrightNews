import Foundation

// MARK: - AdMob 広告設定
// ─────────────────────────────────────────────
// 【AdMob SDK 追加手順 - 必ずビルド前に実施】
//
// 1. Xcodeメニュー → File → Add Package Dependencies
//    URL: https://github.com/googleads/swift-package-manager-google-mobile-ads
//    バージョン選択: Up to Next Major Version（最新）
//    追加するProduct: GoogleMobileAds にチェック → Add Package
//
// 2. このファイルの本番IDはすでに設定済み
// 3. Info.plist の GADApplicationIdentifier も設定済み
// ─────────────────────────────────────────────

enum AdConfig {

    // MARK: - アプリID（本番）
    static let appID = "ca-app-pub-4235363675238841~4605193758"

    // MARK: - 広告ユニットID（本番）
    /// フィード内ネイティブ アドバンス広告
    static let nativeAdUnitID = "ca-app-pub-4235363675238841/7482638539"
    /// 記事詳細画面バナー広告
    static let bannerAdUnitID = "ca-app-pub-4235363675238841/2100385112"

    // MARK: - フィード設定
    /// 何記事ごとにネイティブ広告を1枚挿入するか（5記事に1枚）
    static let adInterval = 5
}
