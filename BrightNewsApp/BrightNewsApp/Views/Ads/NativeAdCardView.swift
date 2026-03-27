import SwiftUI
import Combine             // @Published に必要
import GoogleMobileAds     // v13+: GAD プレフィックスなし

// MARK: - ネイティブ広告カード（フィード内・5記事に1枚）

struct NativeAdCardView: View {

    @StateObject private var loader = NativeAdLoader()

    var body: some View {
        Group {
            if let ad = loader.nativeAd {
                NativeAdRepresentable(nativeAd: ad)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(uiColor: .systemGray4), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            } else {
                NativeAdPlaceholderView()
            }
        }
        .padding(.horizontal)
        .task { loader.load() }
    }
}

// MARK: - 広告ローダー

@MainActor
final class NativeAdLoader: NSObject, ObservableObject {

    @Published var nativeAd: NativeAd?          // v13: GADNativeAd → NativeAd
    private var adLoader: AdLoader?             // v13: GADAdLoader → AdLoader

    func load() {
        guard nativeAd == nil else { return }

        let rootVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController

        adLoader = AdLoader(
            adUnitID: AdConfig.nativeAdUnitID,
            rootViewController: rootVC,
            adTypes: [.native],
            options: nil
        )
        adLoader?.delegate = self
        adLoader?.load(Request())               // v13: GADRequest → Request
    }
}

extension NativeAdLoader: NativeAdLoaderDelegate { // v13: GADNativeAdLoaderDelegate → NativeAdLoaderDelegate

    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in self.nativeAd = nativeAd }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("BrightNews: ネイティブ広告失敗 - \(error.localizedDescription)")
    }
}

// MARK: - UIViewRepresentable ラッパー

private struct NativeAdRepresentable: UIViewRepresentable {

    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdView { // v13: GADNativeAdView → NativeAdView
        let adView = NativeAdContentView()
        adView.configure(with: nativeAd)
        return adView
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {
        (uiView as? NativeAdContentView)?.configure(with: nativeAd)
    }
}

// MARK: - NativeAdView サブクラス（アセット登録）

private final class NativeAdContentView: NativeAdView { // v13: GADNativeAdView → NativeAdView

    // 広告ラベル（審査要件：広告であることを明示）
    private let adTagLabel: UILabel = {
        let l = UILabel()
        l.text = "広告"; l.font = .systemFont(ofSize: 10, weight: .bold)
        l.textColor = .white
        l.backgroundColor = UIColor.systemGray.withAlphaComponent(0.6)
        l.layer.cornerRadius = 4; l.layer.masksToBounds = true
        l.textAlignment = .center; l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true
        iv.layer.cornerRadius = 10; iv.backgroundColor = .systemGray5
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let headlineLabelView: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold); l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bodyLabelView: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12); l.textColor = .secondaryLabel; l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let ctaButtonView: UIButton = {
        // iOS 15+ は UIButtonConfiguration を使用（contentEdgeInsets 非推奨対応）
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(red: 0.36, green: 0.71, blue: 0.90, alpha: 1.0)
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = UIFont.systemFont(ofSize: 12, weight: .bold); return a
        }
        config.cornerStyle = .fixed
        let btn = UIButton(configuration: config)
        btn.layer.cornerRadius = 8; btn.clipsToBounds = true
        btn.isUserInteractionEnabled = false  // タップは NativeAdView が処理
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override init(frame: CGRect) { super.init(frame: frame); setupLayout() }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with ad: NativeAd) {
        headlineLabelView.text = ad.headline
        bodyLabelView.text     = ad.body ?? ""
        ctaButtonView.setTitle(ad.callToAction ?? "詳しく見る", for: .normal)
        thumbnailImageView.image = ad.images?.first?.image
            ?? UIImage(systemName: "megaphone.fill")

        // AdMob にアセット登録（クリック追跡に必要）
        headlineView     = headlineLabelView
        bodyView         = bodyLabelView
        callToActionView = ctaButtonView
        imageView        = thumbnailImageView
        nativeAd         = ad   // ← 必ず最後にセット
    }

    private func setupLayout() {
        backgroundColor = .systemBackground

        let textStack = UIStackView(arrangedSubviews: [headlineLabelView, bodyLabelView, ctaButtonView])
        textStack.axis = .vertical; textStack.spacing = 5; textStack.alignment = .leading

        let row = UIStackView(arrangedSubviews: [thumbnailImageView, textStack])
        row.axis = .horizontal; row.spacing = 14; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(adTagLabel); addSubview(row)

        NSLayoutConstraint.activate([
            adTagLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            adTagLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            adTagLabel.widthAnchor.constraint(equalToConstant: 26),
            adTagLabel.heightAnchor.constraint(equalToConstant: 16),

            thumbnailImageView.widthAnchor.constraint(equalToConstant: 80),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 80),

            row.topAnchor.constraint(equalTo: adTagLabel.bottomAnchor, constant: 6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }
}

// MARK: - 読み込み中プレースホルダー

private struct NativeAdPlaceholderView: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .systemGray5)).frame(width: 80, height: 80)
                .overlay(Image(systemName: "megaphone.fill").font(.title2).foregroundColor(.gray.opacity(0.4)))
            VStack(alignment: .leading, spacing: 6) {
                Text("広告").font(.caption2.weight(.bold)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.gray.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 4))
                RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .systemGray5)).frame(height: 15)
                RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .systemGray6)).frame(height: 12)
                RoundedRectangle(cornerRadius: 8).fill(Color(uiColor: .systemGray5)).frame(width: 80, height: 28)
            }.frame(maxWidth: .infinity)
        }
        .padding(14).background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(uiColor: .systemGray4), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    NativeAdPlaceholderView().padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
