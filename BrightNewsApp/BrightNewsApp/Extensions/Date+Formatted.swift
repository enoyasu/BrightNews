import Foundation

/// 日付表示用拡張
extension Date {

    /// 相対的な時間表現（例：「2時間前」「昨日」）
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// 短い日付表示（例：「3月27日」）
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: self)
    }

    /// 読みやすい日時（例：「2025年3月27日 08:00」）
    var readableString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: self)
    }
}
