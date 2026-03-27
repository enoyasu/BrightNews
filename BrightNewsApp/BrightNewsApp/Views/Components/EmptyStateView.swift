import SwiftUI

/// データが空のときに表示するビュー
struct EmptyStateView: View {

    let icon: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // アイコン
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(Color.brightPrimary.opacity(0.35))

            // メッセージ
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 40)

            // アクションボタン（任意）
            if let title = actionTitle, let onTap = action {
                Button(action: onTap) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.brightPrimary)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
