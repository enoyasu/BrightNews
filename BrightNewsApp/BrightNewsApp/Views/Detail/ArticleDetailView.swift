import SwiftUI
import WebKit

// MARK: - WKBodyFetcher
/// WKWebView（JavaScript有効）でページ本文を取得するヘルパー
/// URLSessionで空だったJS依存サイト（Yahoo Newsなど）に使用
@MainActor
private final class WKBodyFetcher: NSObject, WKNavigationDelegate {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String, Never>?
    private var jsTimer: Task<Void, Never>?

    func fetch(from urlString: String) async -> String {
        guard let url = URL(string: urlString) else { return "" }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            let config = WKWebViewConfiguration()
            config.preferences.javaScriptEnabled = true
            // バックグラウンドでレンダリング（画面非表示）
            let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                               configuration: config)
            wv.navigationDelegate = self
            wv.load(URLRequest(url: url))
            self.webView = wv

            // 15秒タイムアウト
            jsTimer = Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                self.finish(with: "")
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            // JS レンダリング待ち 1.5秒
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await self.extractText(from: webView)
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFail navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor in self.finish(with: "") }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFailProvisionalNavigation navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor in self.finish(with: "") }
    }

    private func extractText(from webView: WKWebView) async {
        let js = """
        (function() {
            var paragraphs = document.querySelectorAll('p');
            var texts = [];
            for (var i = 0; i < paragraphs.length; i++) {
                var t = paragraphs[i].innerText.trim();
                if (t.length > 20) texts.push(t);
            }
            return texts.join('\\n\\n');
        })()
        """
        let result = try? await webView.evaluateJavaScript(js)
        let text = (result as? String) ?? ""
        finish(with: text)
    }

    private func finish(with text: String) {
        jsTimer?.cancel()
        jsTimer = nil
        webView?.navigationDelegate = nil
        webView = nil
        continuation?.resume(returning: text)
        continuation = nil
    }
}

/// 記事詳細画面
/// ヒーロー画像・本文・元記事リンク・シェア・お気に入りを提供
struct ArticleDetailView: View {

    let article: Article

    @EnvironmentObject var favoritesService: FavoritesService
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var purchaseService: PurchaseService

    @Environment(\.openURL) private var openURL
    @State private var bookmarkScale: CGFloat = 1.0
    @State private var fetchedBody: String = ""
    @State private var isLoadingBody = false

    /// 本文取得後に先頭段落から生成した概要（取得前は article.summary を使用）
    private var displayedSummary: String {
        guard !fetchedBody.isEmpty else { return article.summary }
        // 本文の最初の段落を概要として使用（最大150文字）
        let firstParagraph = fetchedBody
            .components(separatedBy: "\n\n")
            .first(where: { $0.count >= 30 }) ?? ""
        if firstParagraph.isEmpty { return article.summary }
        return firstParagraph.count > 150
            ? String(firstParagraph.prefix(150)) + "…"
            : firstParagraph
    }

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

                        Text(displayedSummary)
                            .font(.system(size: appSettings.fontSize.bodySize))
                            .foregroundColor(.primary)
                            .lineSpacing(7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.brightPrimary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // MARK: 本文（API 概要 ＋ Web フェッチ全文）
                    VStack(alignment: .leading, spacing: 12) {
                        if isLoadingBody {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("記事本文を読み込み中…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if !fetchedBody.isEmpty {
                            Text(fetchedBody)
                                .font(.system(size: appSettings.fontSize.bodySize))
                                .foregroundColor(.primary)
                                .lineSpacing(9)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            // フェッチ失敗 or 未実施 → API 提供のテキストを表示
                            Text(article.content)
                                .font(.system(size: appSettings.fontSize.bodySize))
                                .foregroundColor(.primary)
                                .lineSpacing(9)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()

                    // MARK: アクションボタン
                    VStack(spacing: 12) {

                        // 元記事を読む（デバイスのデフォルトブラウザで開く）
                        if let url = URL(string: article.sourceURL) {
                            Button {
                                openURL(url)
                            } label: {
                                Label("元記事を読む", systemImage: "safari.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.brightPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
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
        .task {
            guard fetchedBody.isEmpty else { return }
            isLoadingBody = true
            // まず URLSession で高速取得
            var body = await NewsService.shared.fetchArticleBody(from: article.sourceURL)
            // 空の場合は WKWebView（JS有効）でフォールバック取得
            if body.isEmpty {
                body = await WKBodyFetcher().fetch(from: article.sourceURL)
            }
            fetchedBody = body
            isLoadingBody = false
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
