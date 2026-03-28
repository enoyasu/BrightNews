import SwiftUI

/// カテゴリ画面
/// 7カテゴリをグリッド表示し、選択するとフィルタリングされた記事一覧を表示
struct CategoryView: View {

    @StateObject private var viewModel = CategoryViewModel()
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var favoritesService: FavoritesService

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: カテゴリグリッド
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("カテゴリを選んでください")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        Text("タップすると関連ニュースがこの画面の下に表示されます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(NewsCategory.allCases) { category in
                            CategoryCardButton(
                                category: category,
                                isSelected: viewModel.selectedCategory == category
                            ) {
                                Task { await viewModel.loadArticles(for: category) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // MARK: 選択中カテゴリの記事一覧
                if let selected = viewModel.selectedCategory {
                    Divider()
                        .padding(.horizontal)

                    // セクションヘッダー
                    HStack(spacing: 8) {
                        Image(systemName: selected.icon)
                            .foregroundColor(selected.color)
                        Text("\(selected.displayName)のニュース")
                            .font(.headline)
                    }
                    .padding(.horizontal)

                    // 記事コンテンツ
                    Group {
                        if viewModel.isLoading {
                            LoadingView()
                        } else if viewModel.articles.isEmpty {
                            EmptyStateView(
                                icon: selected.icon,
                                message: "このカテゴリの記事は\nまだありません"
                            )
                            .padding(.top, 20)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.articles) { article in
                                    NavigationLink(destination: ArticleDetailView(article: article)) {
                                        ArticleCardView(article: article)
                                            .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.brightBackground)
        .navigationTitle("カテゴリ")
    }
}

// MARK: - カテゴリ選択カードボタン
struct CategoryCardButton: View {

    let category: NewsCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // アイコンサークル
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color : category.color.opacity(0.12))
                        .frame(width: 58, height: 58)
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : category.color)
                }

                // ラベル
                VStack(spacing: 2) {
                    Text(category.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(isSelected ? category.color : .primary)

                    Text(category.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? category.color.opacity(0.08) : Color.brightCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.0 : 0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
