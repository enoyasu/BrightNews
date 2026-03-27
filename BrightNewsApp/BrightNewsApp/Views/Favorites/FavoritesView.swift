import SwiftUI

/// お気に入り記事一覧画面
/// ローカル保存された記事を表示・管理
struct FavoritesView: View {

    @EnvironmentObject var favoritesService: FavoritesService
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        Group {
            if favoritesService.favorites.isEmpty {
                // MARK: 空状態
                EmptyStateView(
                    icon: "bookmark",
                    message: "保存した記事がまだありません。\n気になった記事のブックマークを\nタップして保存しましょう ✨"
                )
            } else {
                // MARK: お気に入り一覧
                List {
                    // 件数バッジ
                    HStack {
                        Text("\(favoritesService.favorites.count)件の記事を保存中")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .listRowBackground(Color.brightBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 0, trailing: 16))

                    ForEach(favoritesService.favorites) { article in
                        NavigationLink(destination: ArticleDetailView(article: article)) {
                            ArticleCardView(article: article)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.brightBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                        // 左スワイプで削除
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    favoritesService.toggleFavorite(article)
                                }
                            } label: {
                                Label("削除", systemImage: "trash.fill")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color.brightBackground)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("お気に入り")
    }
}
