import SwiftUI
import SafariServices

/// SFSafariViewController のSwiftUIラッパー
/// 記事の元URL表示に使用（アプリ内ブラウザ）
struct SafariView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true // リーダーモードを優先

        let vc = SFSafariViewController(url: url, configuration: config)
        // iOS 26以降は preferredControlTintColor が非推奨のため条件分岐
        if #unavailable(iOS 26.0) {
            vc.preferredControlTintColor = UIColor(Color.brightPrimary)
        }
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // 更新不要
    }
}
