import Foundation

// MARK: - AdMob 広告設定
// ─────────────────────────────────────────────
// ① Xcodeメニュー → File → Add Package Dependencies
//    URL: https://github.com/googleads/swift-package-manager-google-mobile-ads
//    バージョン: 最新 Exact Version
//
// ② AdMob コンソール（https://admob.google.com）でアプリ登録後、
//    下記 TODO のテスト用IDを本番IDに差し替えてください。
//
// ③ Info.plist に以下を追加してください（キー名と値をそのまま）:
//    Key:   GADApplicationIdentifier
//    Type:  String
//    Value: ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX  ← 本番AppIDに変更
// ─────────────────────────────────────────────

enum AdConfig {

    // MARK: アプリID
    // TODO: AdMobコンソールで取得した本番AppIDに変更
    static let appID = "ca-app-pub-3940256099942544~1458002511"

    // MARK: 広告ユニットID
    // テスト中はこのままでOK。リリース前に本番IDへ変更してください。
    // TODO: AdMob コンソール → 広告ユニット から取得
    static let nativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"  // テスト用
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"  // テスト用

    // MARK: フィード設定
    /// 何記事ごとにネイティブ広告を1枚挿入するか
    static let adInterval = 5
}
