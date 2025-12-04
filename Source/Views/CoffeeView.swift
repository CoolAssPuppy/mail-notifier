//
//  CoffeeView.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import SwiftUI
import StoreKit

struct CoffeeView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showThankYou = false
    @State private var isPurchasing = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            Spacer()

            VStack(spacing: 24) {
                Text("Mail Notifier is free.")
                    .font(.title3)

                Text("But you can buy me coffee")
                    .font(.title2)
                    .fontWeight(.medium)

                if showThankYou {
                    thankYouView
                } else {
                    purchaseView
                }
            }
            .padding()

            Spacer()

            footerView
        }
        .background(.ultraThinMaterial)
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Support Mail Notifier")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Buy Me Coffee")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(.regularMaterial)
    }

    private var thankYouView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Thank you for your support!")
                .font(.title2)
                .fontWeight(.bold)

            Text("Your coffee has been received")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private var purchaseView: some View {
        if storeManager.isLoading {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
        } else if let coffeeProduct = storeManager.products.first(where: { $0.id == ProductIdentifier.coffee.rawValue }) {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(coffeeProduct.displayName)
                        .font(.headline)

                    Text(coffeeProduct.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    Task {
                        await purchaseCoffee(coffeeProduct)
                    }
                }) {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                        Text("Buy Coffee - \(coffeeProduct.displayPrice)")
                    }
                    .font(.title3)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isPurchasing)
                .controlSize(.large)

                if isPurchasing {
                    ProgressView()
                        .padding(.top, 8)
                }

                if storeManager.isPurchased(coffeeProduct.id) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Already purchased - Thank you!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        } else {
            Text("Coffee not available at the moment")
                .font(.body)
                .foregroundColor(.secondary)

            Button("Retry Loading Products") {
                Task {
                    await storeManager.loadProducts()
                }
            }
            .padding(.top, 8)
        }

        if let error = storeManager.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .padding()
        }

        Button("Restore Purchases") {
            Task {
                await storeManager.restorePurchases()
            }
        }
        .buttonStyle(.link)
        .padding(.top, 16)
    }

    private var footerView: some View {
        VStack(spacing: 8) {
            Text("All purchases are one-time and non-consumable")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Thank you for supporting independent development!")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
        .padding()
    }

    private func purchaseCoffee(_ product: Product) async {
        isPurchasing = true

        do {
            let transaction = try await storeManager.purchase(product)

            if transaction != nil {
                withAnimation {
                    showThankYou = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        showThankYou = false
                    }
                }
            }
        } catch {
            Log.app.error("Purchase failed: \(error.localizedDescription)")
        }

        isPurchasing = false
    }
}

#Preview {
    CoffeeView()
}
