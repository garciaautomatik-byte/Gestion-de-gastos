import SwiftUI
import SwiftData

struct InvestmentsListView: View {
    @Query(sort: \Holding.createdAt) private var holdings: [Holding]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddHolding = false
    @State private var isRefreshing = false
    @State private var refreshErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(holdings) { holding in
                    NavigationLink {
                        HoldingDetailView(holding: holding)
                    } label: {
                        HoldingRow(holding: holding)
                    }
                }
                .onDelete(perform: deleteHoldings)
                .listRowBackground(Color.appCard)
            }
            .navigationTitle("Inversiones")
            .themedListBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task { await refreshPrices() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(holdings.isEmpty)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddHolding = true
                    } label: {
                        Label("Añadir", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if holdings.isEmpty {
                    ContentUnavailableView(
                        "Sin inversiones",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Añade tu primera posición con el botón +")
                    )
                }
            }
            .sheet(isPresented: $showingAddHolding) {
                AddHoldingView()
            }
            .alert(
                "Aviso",
                isPresented: Binding(
                    get: { refreshErrorMessage != nil },
                    set: { if !$0 { refreshErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(refreshErrorMessage ?? "")
            }
        }
    }

    private func deleteHoldings(at offsets: IndexSet) {
        for index in offsets {
            let holding = holdings[index]
            for transaction in holding.investmentTransactions {
                transaction.fundingAccount?.currentBalance -= transaction.cashImpact
            }
            modelContext.delete(holding)
        }
    }

    private func refreshPrices() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let service = PriceService()
        var failures: [String] = []

        for holding in holdings {
            do {
                let quote = try await service.fetchQuote(symbol: holding.ticker)
                holding.currentPrice = quote.price
                holding.priceUpdatedAt = .now
                if let currency = quote.currency, !currency.isEmpty {
                    holding.currency = currency
                }
            } catch {
                failures.append("\(holding.ticker): \(error.localizedDescription)")
            }
        }

        try? modelContext.save()

        if !failures.isEmpty {
            refreshErrorMessage = failures.joined(separator: "\n")
        }
    }
}

private struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(holding.ticker)
                    .font(.headline)
                Text(holding.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                if let marketValue = holding.marketValue {
                    Text(marketValue, format: .currency(code: holding.currency))
                } else {
                    Text(holding.quantity, format: .number)
                }
                if let currentPrice = holding.currentPrice {
                    Text("\(currentPrice.formatted(.currency(code: holding.currency)))/ud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(holding.averageCost, format: .currency(code: holding.currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let gainLoss = holding.gainLoss, let percent = holding.gainLossPercent {
                    HStack(spacing: 4) {
                        Text(gainLoss, format: .currency(code: holding.currency).sign(strategy: .always()))
                        Text("(\(percent, format: .percent.precision(.fractionLength(1))))")
                    }
                    .font(.caption2)
                    .foregroundStyle(gainLoss >= 0 ? Color.green : Color.red)
                }
            }
        }
    }
}

#Preview {
    InvestmentsListView()
        .modelContainer(PreviewData.container)
}
