import StoreKit
import SwiftUI

@MainActor
final class TipJar: ObservableObject {
    static let shared = TipJar()
    static let productID = "com.strategicnerds.MailNotifierApp.tip"

    @Published private(set) var product: Product?
    @Published private(set) var loading = false
    @Published private(set) var purchasing = false
    @Published private(set) var message: LocalizedStringKey?

    private var updates: Task<Void, Never>?

    func start() {
        guard updates == nil else { return }
        updates = Task {
            for await result in StoreKit.Transaction.updates {
                await finish(result)
            }
        }
        Task {
            for await result in StoreKit.Transaction.unfinished {
                await finish(result)
            }
        }
    }

    func load() async {
        guard !loading, product == nil else { return }
        loading = true
        defer { loading = false }
        product = try? await Product.products(for: [Self.productID]).first {
            $0.id == Self.productID && $0.type == .consumable
        }
    }

    func sendTip() async {
        guard let product, !purchasing else { return }
        purchasing = true
        message = nil
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                if !(await finish(result)) {
                    message = "The tip could not be verified."
                }
            case .pending:
                message = "Your tip is pending Apple’s approval."
            case .userCancelled:
                break
            @unknown default:
                message = "The tip did not complete."
            }
        } catch {
            message = "The tip did not complete. Please try again."
        }
    }

    @discardableResult
    private func finish(_ result: VerificationResult<StoreKit.Transaction>) async -> Bool {
        guard case .verified(let transaction) = result,
              transaction.productID == Self.productID,
              transaction.productType == .consumable else { return false }
        await transaction.finish()
        if transaction.revocationDate == nil { message = "Thank you for supporting Mail Notifier!" }
        return true
    }
}

struct TipCard: View {
    @ObservedObject private var tipJar = TipJar.shared
    @Environment(\.theme) private var theme

    var body: some View {
        AppCard("Support Mail Notifier") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mail Notifier is free. There are no features to unlock, but if you want to support its development, you are welcome to leave a tip.")
                    .fixedSize(horizontal: false, vertical: true)

                if let product = tipJar.product {
                    AppPrimaryButton(title: "Send a tip · \(product.displayPrice)", isDisabled: tipJar.purchasing) {
                        Task { await tipJar.sendTip() }
                    }
                } else if tipJar.loading {
                    ProgressView("Loading tip price…")
                } else {
                    Text("Tips are unavailable right now.")
                    AppSecondaryButton(title: "Retry") { Task { await tipJar.load() } }
                }

                if let message = tipJar.message {
                    Text(message).accessibilityAddTraits(.updatesFrequently)
                }
            }
            .font(.callout)
            .foregroundStyle(theme.foreground)
        }
        .task { await tipJar.load() }
    }
}
