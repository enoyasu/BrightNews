import SwiftUI

/// 記事読み込み中インジケーター
struct LoadingView: View {

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.brightPrimary)
                .scaleEffect(1.4)

            Text("記事を読み込み中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}
