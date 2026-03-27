import StoreKit
import Combine

// MARK: - エラー定義
enum StoreError: LocalizedError {
    case failedVerification
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .failedVerification: return "購入の検証に失敗しました。"
        case .purchaseFailed:     return "購入処理に失敗しました。"
        }
    }
}

/// サブスクリプション管理サービス（StoreKit 2）
/// プレミアムプランの購入・復元・状態管理を担当
@MainActor
final class PurchaseService: ObservableObject {

    // MARK: - 商品ID
    // TODO: App Store Connect → アプリ内課金 で登録するIDと一致させること
    static let monthlyProductID = "com.brightnews.premium.monthly"  // ¥250/月
    static let yearlyProductID  = "com.brightnews.premium.yearly"   // ¥2,400/年

    // MARK: - Published Properties

    /// プレミアム会員かどうか
    @Published var isPremium: Bool = false

    /// 購入可能な商品一覧
    @Published var products: [Product] = []

    /// 処理中フラグ（ボタンのローディング表示用）
    @Published var isLoading: Bool = false

    /// エラーメッセージ（nilならエラーなし）
    @Published var errorMessage: String? = nil

    // MARK: - Private
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Init

    init() {
        // オフライン時もプレミアム状態を維持するためUserDefaultsで記憶
        isPremium = UserDefaults.standard.bool(forKey: "isPremium")

        // トランザクション更新の継続リスナーを起動
        updateListenerTask = startTransactionListener()

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Public API

    /// 商品情報をApp Storeから取得
    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: [
                Self.monthlyProductID,
                Self.yearlyProductID
            ])
            // 安い順（月額→年額）に並べる
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "商品情報の取得に失敗しました。通信状態を確認してください。"
        }
    }

    /// 商品を購入する
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await refreshEntitlements()
                await transaction.finish()

            case .userCancelled:
                break // キャンセルは正常系

            case .pending:
                // ファミリー共有など承認待ち
                errorMessage = "購入が保留中です。承認後に反映されます。"

            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 以前の購入を復元する
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "購入の復元に失敗しました。"
        }
    }

    // MARK: - Private Helpers

    /// バックグラウンドでトランザクション更新を監視（サブスク更新・失効を自動反映）
    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let tx = try await self.checkVerified(result)
                    await self.refreshEntitlements()
                    await tx.finish()
                } catch {
                    // 検証失敗は無視（App Storeが再試行する）
                }
            }
        }
    }

    /// StoreKitの検証結果を確認してトランザクションを返す
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// 現在の有効なエンタイトルメントを確認してプレミアム状態を更新
    private func refreshEntitlements() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               (tx.productID == Self.monthlyProductID || tx.productID == Self.yearlyProductID),
               tx.revocationDate == nil {
                hasPremium = true
            }
        }
        setPremium(hasPremium)
    }

    /// プレミアム状態を更新（UserDefaultsにも保存）
    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: "isPremium")
    }
}
