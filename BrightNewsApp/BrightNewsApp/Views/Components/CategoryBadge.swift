import SwiftUI

/// カテゴリ表示バッジ
/// アイコン + カテゴリ名をカラフルなピル形状で表示
struct CategoryBadge: View {

    let category: NewsCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2.weight(.semibold))
            Text(category.displayName)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(category.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(category.color.opacity(0.12))
        .clipShape(Capsule())
    }
}
