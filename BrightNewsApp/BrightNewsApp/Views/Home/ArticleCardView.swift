import SwiftUI

/// ホーム画面・お気に入り画面で使用するニュースカードコンポーネント
struct ArticleCardView: View {

    let article: Article

    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var favoritesService: FavoritesService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: サムネイル画像
            BrightImageView(urlString: article.imageURL)
                .frame(height: 200)
                .clipped()
                .overlay(
                    // カテゴリバッジをオーバーレイ
                    HStack {
                        Spacer()
                        favoriteButton
                            .padding(10)
                    },
                    alignment: .topTrailing
                )

            // MARK: テキストコンテンツ
            VStack(alignment: .leading, spacing: 10) {

                // カテゴリバッジ
                CategoryBadge(category: article.category)

                // タイトル
                Text(article.title)
                    .font(.system(size: appSettings.fontSize.titleSize, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // 要約
                Text(article.summary)
                    .font(.system(size: appSettings.fontSize.bodySize - 1))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // メタ情報（配信元 / 日時）
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "newspaper.fill")
                            .font(.caption2)
                            .foregroundColor(Color.brightPrimary.opacity(0.7))
                        Text(article.sourceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(article.publishedAt.relativeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .background(Color.brightCard)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
    }

    // MARK: - お気に入りボタン
    private var favoriteButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                favoritesService.toggleFavorite(article)
            }
        } label: {
            Image(systemName: favoritesService.isFavorite(article) ? "bookmark.fill" : "bookmark")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(favoritesService.isFavorite(article) ? Color.brightPrimary : .white)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
