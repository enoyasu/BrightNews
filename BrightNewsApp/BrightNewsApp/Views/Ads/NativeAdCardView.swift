import SwiftUI

/// ネイティブ広告カード
/// AdMob SDK未導入時はプレースホルダーを表示。
/// SDK追加後は内部のモック部分をGADNativeAdViewに置き換えてください。
///
/// 【AdMob SDK 接続手順】
/// 1. Xcodeで File → Add Package Dependencies
///    URL: https://github.com/googleads/swift-package-manager-google-mobile-ads
/// 2. このファイルを GADNativeAdView の UIViewRepresentable ラッパーに差し替え
/// 3. AdConfig.nativeAdUnitID に本番IDをセット
struct NativeAdCardView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // 広告ラベル（App Store審査要件：広告であることを明示）
            HStack {
                Text("広告")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
            }

            // 広告コンテンツ
            HStack(spacing: 14) {

                // サムネイル
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "megaphone.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    )

                // テキスト
                VStack(alignment: .leading, spacing: 5) {
                    Text("広告タイトル")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("広告の説明テキストがここに入ります")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // CTAボタン
                    Text("詳しく見る")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.brightPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(uiColor: .systemGray4), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

#Preview {
    NativeAdCardView()
        .padding(.vertical)
        .background(Color(uiColor: .systemGroupedBackground))
}
