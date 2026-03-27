import SwiftUI
import SafariServices

/// 記事詳細画面
/// ヒーロー画像・本文・元記事リンク・シェア・お気に入りを提供
struct ArticleDetailView: View {

    let article: Article

    @EnvironmentObject var favoritesService: FavoritesService
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var purchaseService: PurchaseService

    @State private var showSafari = false
    @State private var bookmarkScale: CGFloat = 1.0

    private var isFavorite: Bool {
        favoritesService.isFavorite(article)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: ヒーロー画像
                BrightImageView(urlString: article.imageURL)
                    .frame(height: 280)
                    .clipped()

                VStack(alignment: .leading, spacing: 18) {

                    // MARK: メタ情報行
                    HStack {
                        CategoryBadge(category: article.category)
                        Spacer()
                        Text(article.publishedAt.relativeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // MARK: タイトル
                    Text(article.title)
                        .font(.system(
                            size: appSettings.fontSize.titleSize + 2,
                            weight: .bold,
                            design: .default
                        ))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // MARK: 配信元
                    HStack(spacing: 6) {
                        Image(systemName: "newspaper.fill")
                            .foregroundColor(Color.brightPrimary)
                            .font(.caption)
                        Text(article.sourceName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(article.publishedAt.shortDateString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // MARK: 要約セクション
                    VStack(alignment: .leading, spacing: 8) {
                        Label("記事の概要", systemImage: "text.alignleft")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text(article.summary)
                            .font(.system(size: appSettings.fontSize.bodySize))
                            .foregroundColor(.primary)
                            .lineSpacing(7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.brightPrimary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // MARK: 本文
                    Text(article.content)
                        .font(.system(size: appSettings.fontSize.bodySize))
                        .foregroundColor(.primary)
                        .lineSpacing(9)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    // MARK: アクションボタン
                    VStack(spacing: 12) {

                        // 元記事を読む（SFSafariViewController）
                        if let url = URL(string: article.sourceURL) {
                            Button {
                                showSafari = true
                            } label: {
                                Label("元記事を読む", systemImage: "safari.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.brightPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .sheet(isPresented: $showSafari) {
                                SafariView(url: url)
                                    .ignoresSafeArea()
                            }
                        }

                        // シェアボタン
                        ShareLink(
                            item: URL(string: article.sourceURL) ?? URL(string: "https://example.com")!,
                            subject: Text(article.title),
                            message: Text(article.summary)
                        ) {
                            Label("シェアする", systemImage: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .foregroundColor(Color.brightPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brightPrimary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.brightPrimary.opacity(0.25), lineWidth: 1.5)
                                )
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(18)

                // MARK: バナー広告（プレミアムユーザーは非表示）
                if !purchaseService.isPremium {
                    BannerAdView()
                }
            }
        }
        .background(Color.brightBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // お気に入りボタン
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                        favoritesService.toggleFavorite(article)
                        bookmarkScale = 1.4
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation { bookmarkScale = 1.0 }
                    }
                } label: {
                    Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isFavorite ? Color.brightPrimary : .primary)
                        .scaleEffect(bookmarkScale)
                }
                .accessibilityLabel(isFavorite ? "お気に入りから削除" : "お気に入りに追加")
            }
        }
    }
}
