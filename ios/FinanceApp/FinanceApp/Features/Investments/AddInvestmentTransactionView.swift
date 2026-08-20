import SwiftUI
import SwiftData

struct AddInvestmentTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let holding: Holding

    @Query(sort: \Account.name) private var accounts: [Account]

    private enum EntryMode: String, CaseIterable, Identifiable {
        case amount = "Importe"
        case quantity = "Cantidad"
        var id: String { rawValue }
    }

    @State private var type: InvestmentTransactionType = .buy
    @State private var entryMode: EntryMode = .amount
    @State private var fundingAccount: Account?
    @State private var amountText: String = ""
    @State private var quantityText: String = ""
    @State private var priceText: String = ""
    @State private var feesText: String = ""
    @State private var date: Date = .now

    @State private var fetchedPrice: Decimal?
    @State private var isFetchingPrice = false
    @State private var priceFetchError: String?

    private var eligibleAccounts: [Account] {
        accounts.filter { $0.type != .investmentManual }
    }

    private var usesAmountEntry: Bool {
        type != .dividend && entryMode == .amount
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $type) {
                    Text("Compra").tag(InvestmentTransactionType.buy)
                    Text("Venta").tag(InvestmentTransactionType.sell)
                    Text("Dividendo").tag(InvestmentTransactionType.dividend)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.appCard)

                if eligibleAccounts.isEmpty {
                    Section {
                        Text("Necesitas una cuenta bancaria para registrar el pago o el ingreso de esta operación. Añádela primero en la pestaña Cuentas.")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.appCard)
                } else {
                    Section {
                        Picker("Cuenta de pago", selection: $fundingAccount) {
                            Text("Selecciona una cuenta").tag(Account?.none)
                            ForEach(eligibleAccounts) { account in
                                Text(account.name).tag(Account?.some(account))
                            }
                        }
                    } footer: {
                        Text(fundingAccountFooter)
                    }
                    .listRowBackground(Color.appCard)
                }

                if type != .dividend {
                    Picker("Introducir por", selection: $entryMode) {
                        ForEach(EntryMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.appCard)
                }

                if usesAmountEntry {
                    Section {
                        TextField("Importe (\(holding.currency))", text: $amountText)
                            .keyboardType(.decimalPad)

                        if isFetchingPrice {
                            HStack {
                                ProgressView()
                                Text("Consultando precio actual…")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let price = resolvedPrice {
                            LabeledContent("Precio actual") {
                                Text(price, format: .currency(code: holding.currency))
                            }
                            if let quantity = computedQuantity {
                                LabeledContent("Cantidad estimada") {
                                    Text(quantity, format: .number.precision(.fractionLength(0...6)))
                                }
                            }
                        } else if let priceFetchError {
                            Text(priceFetchError)
                                .foregroundStyle(.secondary)
                            Button("Reintentar") {
                                Task { await fetchCurrentPrice() }
                            }
                        }
                    }
                    .listRowBackground(Color.appCard)
                } else {
                    TextField("Cantidad", text: $quantityText)
                        .keyboardType(.decimalPad)
                        .listRowBackground(Color.appCard)
                    TextField("Precio por unidad", text: $priceText)
                        .keyboardType(.decimalPad)
                        .listRowBackground(Color.appCard)
                }

                TextField("Comisiones", text: $feesText)
                    .keyboardType(.decimalPad)
                    .listRowBackground(Color.appCard)
                DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    .listRowBackground(Color.appCard)
            }
            .navigationTitle("Nueva operación")
            .themedListBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!isValid)
                }
            }
            .task {
                if priceText.isEmpty, let currentPrice = holding.currentPrice {
                    priceText = NSDecimalNumber(decimal: currentPrice).stringValue
                }
                if fundingAccount == nil {
                    fundingAccount = eligibleAccounts.first
                }
                if usesAmountEntry {
                    await fetchCurrentPrice()
                }
            }
            .onChange(of: entryMode) {
                if usesAmountEntry && resolvedPrice == nil {
                    Task { await fetchCurrentPrice() }
                }
            }
        }
    }

    private var fundingAccountFooter: String {
        switch type {
        case .buy: return "Se descontará el importe de esta cuenta."
        case .sell: return "Se ingresará el importe en esta cuenta."
        case .dividend: return "Se ingresará el dividendo en esta cuenta."
        }
    }

    private var resolvedPrice: Decimal? {
        fetchedPrice ?? holding.currentPrice
    }

    private var isValid: Bool {
        guard fundingAccount != nil else { return false }
        if usesAmountEntry {
            return parsedAmount != nil && resolvedPrice != nil
        }
        return parsedQuantity != nil && parsedPrice != nil
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var computedQuantity: Decimal? {
        guard let amount = parsedAmount, let price = resolvedPrice, price > 0 else { return nil }
        return amount / price
    }

    private var parsedQuantity: Decimal? {
        Decimal(string: quantityText.replacingOccurrences(of: ",", with: "."))
    }

    private var parsedPrice: Decimal? {
        Decimal(string: priceText.replacingOccurrences(of: ",", with: "."))
    }

    private func fetchCurrentPrice() async {
        isFetchingPrice = true
        priceFetchError = nil
        defer { isFetchingPrice = false }

        do {
            let quote = try await PriceService().fetchQuote(symbol: holding.ticker)
            fetchedPrice = quote.price
            // Keep the holding's cached price in sync as a side effect of this lookup.
            holding.currentPrice = quote.price
            holding.priceUpdatedAt = .now
            if let currency = quote.currency, !currency.isEmpty {
                holding.currency = currency
            }
        } catch {
            priceFetchError = "No se pudo obtener el precio actual: \(error.localizedDescription)"
        }
    }

    private func save() {
        guard let fundingAccount else { return }
        let fees = Decimal(string: feesText.replacingOccurrences(of: ",", with: ".")) ?? 0

        let quantity: Decimal
        let price: Decimal
        if usesAmountEntry {
            guard let amount = parsedAmount, let marketPrice = resolvedPrice, marketPrice > 0 else { return }
            price = marketPrice
            quantity = amount / marketPrice
        } else {
            guard let q = parsedQuantity, let p = parsedPrice else { return }
            quantity = q
            price = p
        }

        let transaction = InvestmentTransaction(
            type: type,
            quantity: quantity,
            pricePerUnit: price,
            date: date,
            fees: fees,
            holding: holding,
            fundingAccount: fundingAccount
        )
        modelContext.insert(transaction)
        fundingAccount.currentBalance += transaction.cashImpact
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddInvestmentTransactionView(holding: Holding(ticker: "AAPL", name: "Apple Inc.", assetType: .stock))
    }
    .modelContainer(PreviewData.container)
}
