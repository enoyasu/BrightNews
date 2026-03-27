import SwiftUI
import GoogleMobileAds

// MARK: - バナー広告ビュー（記事詳細画面下部）
// アダプティブバナー：画面幅に合わせて自動リサイズ
// 表示位置：ArticleDetailView のスクロール最下部

struct BannerAdView: View {
    /// 広告の実際の高さ（広告ロード後に動的に更新）
    @State private var adHeight: CGFloat = 50

    var body: some View {
        BannerAdRepresentable(adHeight: $adHeight)
            .frame(width: UIScreen.main.bounds.width, height: adHeight)
            .background(Color(uiColor: .systemGray6))
            .overlay(alignment: .top) {
                // 上ボーダーライン
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(uiColor: .systemGray4))
            }
    }
}

// MARK: - UIViewRepresentable ラッパー

private struct BannerAdRepresentable: UIViewRepresentable {

    @Binding var adHeight: CGFloat

    func makeUIView(context: Context) -> GADBannerView {
        // アダプティブバナー（画面幅に合わせた最適サイズ）
        let width = UIScreen.main.bounds.width
        let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)

        let bannerView = GADBannerView(adSize: adSize)
        bannerView.adUnitID = AdConfig.bannerAdUnitID
        bannerView.rootViewController = context.coordinator.rootViewController
        bannerView.delegate = context.coordinator
        bannerView.load(GADRequest())
        return bannerView
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(adHeight: $adHeight)
    }

    // MARK: - Coordinator（GADBannerViewDelegate）

    final class Coordinator: NSObject, GADBannerViewDelegate {

        @Binding var adHeight: CGFloat

        init(adHeight: Binding<CGFloat>) {
            _adHeight = adHeight
        }

        /// キーウィンドウの rootViewController を取得
        var rootViewController: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        }

        // 広告ロード成功 → 実際の高さに更新
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            DispatchQueue.main.async {
                self.adHeight = bannerView.adSize.size.height
            }
        }

        // 広告ロード失敗
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("BrightNews: バナー広告読み込み失敗 - \(error.localizedDescription)")
        }
    }
}

#Preview {
    BannerAdView()
}
