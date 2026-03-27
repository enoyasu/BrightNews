import SwiftUI
import GoogleMobileAds

// MARK: - ネイティブ広告カード（フィード内に5記事ごとに1枚表示）

struct NativeAdCardView: View {

    @StateObject private var loader = NativeAdLoader()

    var body: some View {
        Group {
            if let nativeAd = loader.nativeAd {
                // ──── 実広告（AdMob SDK から受信） ────
                NativeAdRepresentable(nativeAd: nativeAd)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(uiColor: .systemGray4), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            } else {
                // ──── 読み込み中プレースホルダー ────
                NativeAdPlaceholderView()
            }
        }
        .padding(.horizontal)
        .task { loader.load() }
    }
}

// MARK: - ネイティブ広告ローダー

/// GADAdLoader を使って1枚のネイティブ広告を取得・保持する ObservableObject
@MainActor
final class NativeAdLoader: NSObject, ObservableObject {

    @Published var nativeAd: GADNativeAd?
    private var adLoader: GADAdLoader?

    func load() {
        guard nativeAd == nil else { return } // 既にロード済みなら再取得しない

        let rootVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController

        adLoader = GADAdLoader(
            adUnitID: AdConfig.nativeAdUnitID,
            rootViewController: rootVC,
            adTypes: [.native],
            options: nil
        )
        adLoader?.delegate = self
        adLoader?.load(GADRequest())
    }
}

// GADNativeAdLoaderDelegate は nonisolated で実装
extension NativeAdLoader: GADNativeAdLoaderDelegate {

    nonisolated func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        Task { @MainActor in self.nativeAd = nativeAd }
    }

    nonisolated func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        print("BrightNews: ネイティブ広告読み込み失敗 - \(error.localizedDescription)")
    }
}

// MARK: - UIViewRepresentable ラッパー

/// GADNativeAdView（UIKit）を SwiftUI に橋渡しする
private struct NativeAdRepresentable: UIViewRepresentable {

    let nativeAd: GADNativeAd

    func makeUIView(context: Context) -> GADNativeAdView {
        let adView = NativeAdContentView()
        adView.configure(with: nativeAd)
        return adView
    }

    func updateUIView(_ uiView: GADNativeAdView, context: Context) {
        (uiView as? NativeAdContentView)?.configure(with: nativeAd)
    }
}

// MARK: - GADNativeAdView サブクラス（レイアウト・アセット登録）

/// AdMob が要求する GADNativeAdView のカスタム実装
/// ・すべての広告アセット（ヘッドライン・ボディ・画像・CTA）を登録する
/// ・nativeAd は必ずアセット登録の「最後」にセットすること
private final class NativeAdContentView: GADNativeAdView {

    // MARK: 広告ラベル（審査要件：広告であることを明示）
    private let adTagLabel: UILabel = {
        let label = UILabel()
        label.text = "広告"
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.backgroundColor = UIColor.systemGray.withAlphaComponent(0.6)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: サムネイル画像
    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.backgroundColor = UIColor.systemGray5
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: ヘッドライン（広告タイトル）
    private let headlineLabelView: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: ボディ（広告説明文）
    private let bodyLabelView: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: CTAボタン（Call to Action）
    private let ctaButtonView: UIButton = {
        let btn = UIButton(type: .custom)
        btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(red: 0.36, green: 0.71, blue: 0.90, alpha: 1.0)
        btn.layer.cornerRadius = 8
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        // タップはGADNativeAdViewが処理するため、ボタン自体はユーザーインタラクション無効
        btn.isUserInteractionEnabled = false
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: 広告コンテンツを設定してアセットを登録

    func configure(with ad: GADNativeAd) {
        headlineLabelView.text = ad.headline
        bodyLabelView.text     = ad.body ?? ""
        ctaButtonView.setTitle(ad.callToAction ?? "詳しく見る", for: .normal)

        if let firstImage = ad.images?.first {
            thumbnailImageView.image = firstImage.image
        } else {
            thumbnailImageView.image = UIImage(systemName: "megaphone.fill")
            thumbnailImageView.tintColor = .systemGray3
        }

        // AdMob に各UIビューを登録（広告クリック追跡に必要）
        headlineView    = headlineLabelView
        bodyView        = bodyLabelView
        callToActionView = ctaButtonView
        imageView       = thumbnailImageView

        // 必ず最後に nativeAd をセット（これより前に設定するとクラッシュ）
        nativeAd = ad
    }

    // MARK: レイアウト

    private func setupLayout() {
        backgroundColor = .systemBackground

        // テキスト系を縦に並べるスタック
        let textStack = UIStackView(arrangedSubviews: [
            headlineLabelView,
            bodyLabelView,
            ctaButtonView
        ])
        textStack.axis      = .vertical
        textStack.spacing   = 5
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // 画像 + テキストを横に並べるスタック
        let contentStack = UIStackView(arrangedSubviews: [thumbnailImageView, textStack])
        contentStack.axis      = .horizontal
        contentStack.spacing   = 14
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(adTagLabel)
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            // 広告ラベル：左上
            adTagLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            adTagLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            adTagLabel.widthAnchor.constraint(equalToConstant: 26),
            adTagLabel.heightAnchor.constraint(equalToConstant: 16),

            // サムネイル：80×80 固定
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 80),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 80),

            // コンテンツ全体
            contentStack.topAnchor.constraint(equalTo: adTagLabel.bottomAnchor, constant: 6),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }
}

// MARK: - 読み込み中プレースホルダー（シマー風）

private struct NativeAdPlaceholderView: View {

    var body: some View {
        HStack(spacing: 14) {
            // サムネイル枠
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .systemGray5))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "megaphone.fill")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.4))
                )

            // テキスト枠
            VStack(alignment: .leading, spacing: 6) {
                // 広告タグ
                Text("広告")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // タイトル枠
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(uiColor: .systemGray5))
                    .frame(height: 15)

                // 説明文枠
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(uiColor: .systemGray6))
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)

                // CTAボタン枠
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .systemGray5))
                    .frame(width: 80, height: 28)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(uiColor: .systemGray4), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    NativeAdPlaceholderView()
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
