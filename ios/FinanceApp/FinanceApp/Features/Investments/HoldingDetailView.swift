import SwiftUI
import SwiftData

struct HoldingDetailView: View {
    @Bindable var holding: Holding
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddTransaction = false
    @State private var showingDeleteConfirmation = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private var sortedTransactions: [InvestmentTransaction] {
        holding.investmentTransactions.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section("Posición") {
                LabeledContent("Cantidad") {
                    Text(holding.quantity, format: .number)
                }
                LabeledContent("Coste medio") {
                    Text(holding.averageCost, format: .currency(code: holding.currency))
                }
                if let currentPrice = holding.currentPrice {
                    LabeledContent("Precio actual") {
                        Text(currentPrice, format: .currency(code: holding.currency))
                    }
                }
                LabeledContent("Coste total") {
                    Text(holding.totalCost, format: .currency(code: holding.currency))
                }
                if let marketValue = holding.marketValue {
                    LabeledContent("Valor de mercado") {
                        Text(marketValue, format: .currency(code: holding.currency))
                    }
                }
                if let gainLoss = holding.gainLoss, let percent = holding.gainLossPercent {
                    LabeledContent("Rentabilidad") {
                        HStack(spacing: 4) {
                            Text(gainLoss, format: .currency(code: holding.currency).sign(strategy: .always()))
                            Text("(\(percent, format: .percent.precision(.fractionLength(1))))")
                        }
                        .foregroundStyle(gainLoss >= 0 ? Color.green : Color.red)
                    }
                }
                if let updatedAt = holding.priceUpdatedAt {
                    LabeledContent("Precio actualizado") {
                        Text(updatedAt, style: .relative)
                    }
                }
                if let exchange = holding.exchange {
                    LabeledContent("Bolsa", value: exchange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color.appCard)

            Section("Operaciones") {
                ForEach(sortedTransactions) { tx in
                    InvestmentTransactionRow(transaction: tx, currency: holding.currency)
                }
                .onDelete(perform: deleteTransactions)
            }
            .listRowBackground(Color.appCard)
        }
        .navigationTitle(holding.ticker)
        .themedListBackground()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isRefreshing {
                    ProgressView()
                } else {
                    Button {
                        Task { await refreshPrice() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTransaction = true
                } label: {
                    Label("Añadir operación", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddInvestmentTransactionView(holding: holding)
        }
        .alert(
            "Aviso",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "¿Eliminar \(holding.ticker)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar posición", role: .destructive) {
                for transaction in holding.investmentTransactions {
                    transaction.fundingAccount?.currentBalance -= transaction.cashImpact
                }
                modelContext.delete(holding)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrarán también todas sus operaciones de compra, venta y dividendo.")
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        let items = sortedTransactions
        for index in offsets {
            let transaction = items[index]
            transaction.fundingAccount?.currentBalance -= transaction.cashImpact
            modelContext.delete(transaction)
        }
    }

    private func refreshPrice() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let quote = try await PriceService().fetchQuote(symbol: holding.ticker)
            holding.currentPrice = quote.price
            holding.priceUpdatedAt = .now
            if let currency = quote.currency, !currency.isEmpty {
                holding.currency = currency
            }
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct InvestmentTransactionRow: View {
    let transaction: InvestmentTransaction
    let currency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(label)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let accountName = transaction.fundingAccount?.name {
                    Text(accountName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(transaction.quantity, format: .number)
                Text(transaction.pricePerUnit, format: .currency(code: currency))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var label: String {
        switch transaction.type {
        case .buy: return "Compra"
        case .sell: return "Venta"
        case .dividend: return "Dividendo"
        }
    }
}
