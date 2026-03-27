import SwiftUI
import StoreKit

/// プレミアムプラン購入画面
/// 広告除去サブスクリプションの購入・復元をユーザーに提供する
struct PremiumView: View {

    @EnvironmentObject var purchaseService: PurchaseService
    @Environment(\.dismiss) private var dismiss

    // MARK: - プレミアム特典リスト
    private let benefits: [(icon: String, color: Color, text: String)] = [
        ("xmark.circle.fill",     .red,    "すべての広告を非表示"),
        ("bolt.fill",             .orange, "より快適な読み心地"),
        ("star.fill",             .yellow, "開発者の活動を応援"),
        ("heart.fill",            .pink,   "BrightNewsの継続的な運営を支援"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // MARK: ヒーローセクション
                    VStack(spacing: 12) {
                        Text("☀️")
                            .font(.system(size: 64))

                        Text("BrightNews Premium")
                            .font(.title2.weight(.bold))

                        Text("広告なしで、もっと気持ちよく。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // MARK: 特典リスト
                    VStack(spacing: 0) {
                        ForEach(Array(benefits.enumerated()), id: \.offset) { _, benefit in
                            HStack(spacing: 14) {
                                Image(systemName: benefit.icon)
                                    .font(.title3)
                                    .foregroundColor(benefit.color)
                                    .frame(width: 32)

                                Text(benefit.text)
                                    .font(.body)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)

                            if benefit.text != benefits.last?.text {
                                Divider().padding(.leading, 66)
                            }
                        }
                    }
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // MARK: 購入ボタン
                    VStack(spacing: 12) {
                        if purchaseService.isLoading {
                            ProgressView()
                                .tint(Color.brightPrimary)
                                .frame(height: 52)
                        } else if purchaseService.products.isEmpty {
                            // 商品読み込み中
                            Text("商品情報を読み込み中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: 52)
                                .onAppear {
                                    Task { await purchaseService.loadProducts() }
                                }
                        } else {
                            // 商品ボタンを表示
                            ForEach(purchaseService.products, id: \.id) { product in
                                PurchaseButton(product: product) {
                                    Task { await purchaseService.purchase(product) }
                                }
                            }
                        }

                        // 購入復元ボタン
                        Button {
                            Task { await purchaseService.restorePurchases() }
                        } label: {
                            Text("以前の購入を復元する")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .disabled(purchaseService.isLoading)
                    }
                    .padding(.horizontal)

                    // MARK: エラー表示
                    if let error = purchaseService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // MARK: 注意事項
                    VStack(alignment: .leading, spacing: 4) {
                        Text("・サブスクリプションはiTunesアカウントに請求されます。")
                        Text("・購読は現在の期間終了の24時間前に自動更新されます。")
                        Text("・購読の管理・解除はiOSの設定アプリから行えます。")
                        Text("・無料トライアル期間中の解約は請求されません。")
                    }
                    .font(.caption2)
                    .foregroundColor(Color(uiColor: .systemGray2))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(Color.brightPrimary)
                }
            }
        }
        // 購入成功時に自動で閉じる
        .onChange(of: purchaseService.isPremium) { _, newValue in
            if newValue { dismiss() }
        }
    }
}

// MARK: - 購入ボタン（商品ごと）
private struct PurchaseButton: View {

    let product: Product
    let action: () -> Void

    private var isMonthly: Bool {
        product.id == PurchaseService.monthlyProductID
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isMonthly ? "月額プラン" : "年額プラン")
                        .font(.body.weight(.semibold))
                    if !isMonthly {
                        Text("約17%お得")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                    Text(isMonthly ? "/ 月" : "/ 年")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isMonthly {
                        Color.brightPrimary
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.36, green: 0.71, blue: 0.90),
                                     Color(red: 0.93, green: 0.67, blue: 0.18)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    PremiumView()
        .environmentObject(PurchaseService())
}
