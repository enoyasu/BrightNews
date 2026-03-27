import SwiftUI
import GoogleMobileAds  // v13+: GAD プレフィックスなし

// MARK: - バナー広告ビュー（記事詳細画面下部）
// アダプティブバナー：画面幅に自動フィット

struct BannerAdView: View {
    @State private var adHeight: CGFloat = 50

    var body: some View {
        BannerAdRepresentable(adHeight: $adHeight)
            .frame(width: UIScreen.main.bounds.width, height: adHeight)
            .background(Color(uiColor: .systemGray6))
            .overlay(alignment: .top) {
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(uiColor: .systemGray4))
            }
    }
}

// MARK: - UIViewRepresentable ラッパー

private struct BannerAdRepresentable: UIViewRepresentable {

    @Binding var adHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(adHeight: $adHeight) }

    func makeUIView(context: Context) -> BannerView {
        // v13: GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth
        //      → currentOrientationAnchoredAdaptiveBannerAdSize(withWidth:)
        let width = UIScreen.main.bounds.width
        let adSize = largeAnchoredAdaptiveBanner(width: width)

        let banner = BannerView(adSize: adSize)           // v13: GADBannerView → BannerView
        banner.adUnitID = AdConfig.bannerAdUnitID
        banner.rootViewController = context.coordinator.rootViewController
        banner.delegate = context.coordinator
        banner.load(Request())                            // v13: GADRequest → Request
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    // MARK: Coordinator（BannerViewDelegate）

    final class Coordinator: NSObject, BannerViewDelegate { // v13: GADBannerViewDelegate → BannerViewDelegate

        @Binding var adHeight: CGFloat
        init(adHeight: Binding<CGFloat>) { _adHeight = adHeight }

        var rootViewController: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        }

        // 広告ロード成功 → 実際の高さに更新
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            DispatchQueue.main.async { self.adHeight = bannerView.adSize.size.height }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("BrightNews: バナー広告失敗 - \(error.localizedDescription)")
        }
    }
}

#Preview { BannerAdView() }
