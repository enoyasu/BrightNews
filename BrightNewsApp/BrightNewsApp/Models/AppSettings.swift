import SwiftUI
import Combine

/// アプリ全体の設定を管理するクラス
/// @Published + UserDefaults で永続化（@AppStorage は ObservableObject と競合するため非使用）
final class AppSettings: ObservableObject {

    // MARK: - Published Properties（変更時に View へ自動通知）

    /// 通知の有効/無効
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    /// 通知時刻（時）
    @Published var notificationHour: Int {
        didSet { UserDefaults.standard.set(notificationHour, forKey: "notificationHour") }
    }

    /// 通知時刻（分）
    @Published var notificationMinute: Int {
        didSet { UserDefaults.standard.set(notificationMinute, forKey: "notificationMinute") }
    }

    /// 文字サイズ（内部保存用 RawValue）
    @Published private var fontSizeRaw: String {
        didSet { UserDefaults.standard.set(fontSizeRaw, forKey: "fontSizeRaw") }
    }

    /// 文字サイズの列挙型アクセサ
    var fontSize: FontSize {
        get { FontSize(rawValue: fontSizeRaw) ?? .medium }
        set { fontSizeRaw = newValue.rawValue }
    }

    // MARK: - Init（UserDefaults から読み込み）

    init() {
        let ud = UserDefaults.standard
        notificationsEnabled = ud.object(forKey: "notificationsEnabled") as? Bool ?? true
        notificationHour     = ud.object(forKey: "notificationHour")     as? Int  ?? 8
        notificationMinute   = ud.object(forKey: "notificationMinute")   as? Int  ?? 0
        fontSizeRaw          = ud.string(forKey: "fontSizeRaw")          ?? FontSize.medium.rawValue
    }
}

// MARK: - 文字サイズ定義
/// アプリ内で使用する文字サイズの選択肢
enum FontSize: String, CaseIterable {
    case small  = "small"
    case medium = "medium"
    case large  = "large"

    /// 表示名（日本語）
    var displayName: String {
        switch self {
        case .small:  return "小"
        case .medium: return "中"
        case .large:  return "大"
        }
    }

    /// 本文フォントサイズ
    var bodySize: CGFloat {
        switch self {
        case .small:  return 14
        case .medium: return 16
        case .large:  return 18
        }
    }

    /// タイトルフォントサイズ
    var titleSize: CGFloat {
        switch self {
        case .small:  return 17
        case .medium: return 20
        case .large:  return 23
        }
    }
}
