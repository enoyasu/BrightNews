import SwiftUI

/// バナー広告ビュー（記事詳細画面下部に表示）
/// AdMob SDK未導入時はプレースホルダーを表示。
/// SDK追加後は GADBannerView の UIViewRepresentable ラッパーに差し替えてください。
///
/// 【AdMob SDK 接続手順】
/// 1. Package追加後に import GoogleMobileAds を追加
/// 2. GADBannerView を UIViewRepresentable でラップ
/// 3. AdConfig.bannerAdUnitID に本番IDをセット
/// 標準サイズ: 320×50pt（GADAdSizeBanner）
struct BannerAdView: View {

    var body: some View {
        HStack(spacing: 8) {

            // 広告ラベル（App Store審査要件）
            Text("広告")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Spacer()

            Text("スポンサー")
                .font(.caption)
                .foregroundColor(Color(uiColor: .systemGray2))

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color(uiColor: .systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(uiColor: .systemGray4)),
            alignment: .top
        )
    }
}

#Preview {
    BannerAdView()
}
