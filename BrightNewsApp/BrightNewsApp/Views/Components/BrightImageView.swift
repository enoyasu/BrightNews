import SwiftUI

/// 非同期画像読み込みコンポーネント
/// 読み込み中・エラー時のプレースホルダーを自動表示
struct BrightImageView: View {

    let urlString: String

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // 読み込み中：スケルトン風プレースホルダー
                        skeletonPlaceholder

                    case .success(let image):
                        // 読み込み成功：フェードインアニメーション付き
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity.animation(.easeInOut(duration: 0.4)))

                    case .failure:
                        // 読み込み失敗：サンシャインプレースホルダー
                        sunPlaceholder

                    @unknown default:
                        sunPlaceholder
                    }
                }
            } else {
                sunPlaceholder
            }
        }
    }

    // MARK: - Placeholder Views

    /// スケルトン読み込みプレースホルダー
    private var skeletonPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.08)
            ProgressView()
                .tint(Color.brightPrimary)
        }
    }

    /// 画像取得失敗時のサンシャイングラデーション
    private var sunPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.88, blue: 0.62),
                    Color(red: 1.0, green: 0.68, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "sun.max.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}
