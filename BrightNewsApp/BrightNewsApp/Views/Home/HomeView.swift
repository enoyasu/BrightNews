import SwiftUI

/// ホーム画面
/// おすすめニュース一覧をカード形式で表示。無限スクロール・プルリフレッシュ対応
struct HomeView: View {

    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var favoritesService: FavoritesService
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var purchaseService: PurchaseService

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {

                // MARK: ウェルカムバナー
                WelcomeBanner()
                    .padding(.horizontal)

                // MARK: コンテンツ
                if viewModel.isLoading {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage {
                    EmptyStateView(
                        icon: "wifi.exclamationmark",
                        message: errorMessage,
                        actionTitle: "もう一度試す"
                    ) {
                        Task { await viewModel.loadArticles() }
                    }
                    .padding(.top, 40)
                } else {
                    // 記事＋広告の混合フィード
                    ForEach(viewModel.feedItems) { item in
                        switch item {
                        case .article(let article):
                            NavigationLink(destination: ArticleDetailView(article: article)) {
                                ArticleCardView(article: article)
                                    .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                            // 最後のアイテムが表示されたら追加読み込み
                            .onAppear {
                                if article.id == viewModel.articles.last?.id {
                                    Task { await viewModel.loadMoreArticles(
                                        isPremium: purchaseService.isPremium) }
                                }
                            }

                        case .nativeAd:
                            NativeAdCardView()
                        }
                    }

                    // 追加読み込みインジケーター
                    if viewModel.isLoadingMore {
                        HStack {
                            ProgressView()
                                .tint(Color.brightPrimary)
                            Text("さらに読み込み中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                    }

                    // フッター
                    if !viewModel.hasMore {
                        Text("すべての記事を表示しました ☀️")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.brightBackground)
        .navigationTitle("BrightNews")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: FavoritesView()) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(Color.brightPrimary)
                }
            }
        }
        .refreshable {
            await viewModel.refresh(isPremium: purchaseService.isPremium)
        }
        .task {
            if viewModel.articles.isEmpty {
                await viewModel.loadArticles(isPremium: purchaseService.isPremium)
            }
        }
        // プレミアム状態が変わったらフィードを再構築（広告の表示/非表示を即時反映）
        .onChange(of: purchaseService.isPremium) { _, _ in
            Task { await viewModel.refresh(isPremium: purchaseService.isPremium) }
        }
        // 画面表示時に自動更新タイマー開始（5分ごとチェック・1時間で再取得）
        .onAppear {
            viewModel.startAutoRefresh(isPremium: purchaseService.isPremium)
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
}

// MARK: - ウェルカムバナー
private struct WelcomeBanner: View {

    // 時間帯に応じた挨拶
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "おはようございます"
        case 12..<17: return "こんにちは"
        case 17..<21: return "こんにちは"
        default:       return "お疲れさまでした"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brightGradientStart, Color.brightGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    Text("今日も良いニュースをお届けします")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.88))
                }
                Spacer()
                Text("🌸")
                    .font(.system(size: 56))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(height: 110)
        .shadow(color: Color.brightPrimary.opacity(0.30), radius: 12, x: 0, y: 4)
    }
}
