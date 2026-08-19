import SwiftUI
import SwiftData
import Charts

private struct MonthlySummary: Identifiable {
    let id: Date
    let label: String
    let income: Decimal
    let expense: Decimal
}

struct DashboardView: View {
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \MoneyTransaction.date, order: .reverse) private var transactions: [MoneyTransaction]
    @Query private var holdings: [Holding]

    private var totalBalance: Decimal {
        accounts
            .filter { $0.type != .investmentManual }
            .reduce(Decimal(0)) { $0 + $1.currentBalance }
    }

    /// Market value where we have a live price, cost basis otherwise — so a position never
    /// reads as zero just because its price hasn't been refreshed yet.
    private var totalInvestmentValue: Decimal {
        holdings.reduce(Decimal(0)) { $0 + ($1.marketValue ?? $1.totalCost) }
    }

    private var netWorth: Decimal {
        totalBalance + totalInvestmentValue
    }

    private var totalInvestmentCost: Decimal {
        holdings.reduce(Decimal(0)) { $0 + $1.totalCost }
    }

    // Only holdings with a refreshed price contribute to gain/loss — otherwise "rentabilidad"
    // would misleadingly read as 0 instead of simply unknown.
    private var pricedHoldings: [Holding] {
        holdings.filter { $0.currentPrice != nil }
    }

    private var totalGainLoss: Decimal {
        pricedHoldings.reduce(Decimal(0)) { $0 + ($1.gainLoss ?? 0) }
    }

    private var totalGainLossPercent: Double? {
        let cost = pricedHoldings.reduce(Decimal(0)) { $0 + $1.totalCost }
        guard cost > 0 else { return nil }
        return NSDecimalNumber(decimal: totalGainLoss / cost).doubleValue
    }

    private var recentTransactions: [MoneyTransaction] {
        Array(transactions.prefix(5))
    }

    private var spendByCategory: [(category: String, total: Decimal)] {
        let expenseTx = transactions.filter { $0.amount < 0 && !$0.isTransfer }
        let grouped = Dictionary(grouping: expenseTx) { $0.category?.name ?? "Sin categoría" }
        return grouped
            .map { (category: $0.key, total: abs($0.value.reduce(Decimal(0)) { $0 + $1.amount })) }
            .sorted { $0.total > $1.total }
    }

    /// Last 6 calendar months (oldest first, so the chart reads left-to-right chronologically),
    /// including months with no activity so gaps are visible rather than skipped.
    private var monthlySummaries: [MonthlySummary] {
        let calendar = Calendar.current
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: .now)?.start else { return [] }

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        formatter.locale = Locale(identifier: "es_ES")

        return (0..<6).reversed().compactMap { offset -> MonthlySummary? in
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) else { return nil }
            let monthTx = transactions.filter {
                !$0.isTransfer && calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month)
            }
            let income = monthTx.filter { $0.amount > 0 }.reduce(Decimal(0)) { $0 + $1.amount }
            let expense = monthTx.filter { $0.amount < 0 }.reduce(Decimal(0)) { $0 + abs($1.amount) }
            return MonthlySummary(id: monthStart, label: formatter.string(from: monthStart).capitalized, income: income, expense: expense)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Saldo total") {
                    Text(netWorth, format: .currency(code: "EUR"))
                        .font(.largeTitle.bold())

                    if !holdings.isEmpty {
                        LabeledContent("Cuentas") {
                            Text(totalBalance, format: .currency(code: "EUR"))
                        }
                        LabeledContent("Inversiones") {
                            Text(totalInvestmentValue, format: .currency(code: "EUR"))
                        }
                    }
                }

                if monthlySummaries.contains(where: { $0.income > 0 || $0.expense > 0 }) {
                    Section("Ingresos y gastos por mes") {
                        Chart(monthlySummaries) { summary in
                            BarMark(
                                x: .value("Mes", summary.label),
                                y: .value("Importe", NSDecimalNumber(decimal: summary.income).doubleValue)
                            )
                            .foregroundStyle(by: .value("Tipo", "Ingresos"))
                            .position(by: .value("Tipo", "Ingresos"))

                            BarMark(
                                x: .value("Mes", summary.label),
                                y: .value("Importe", NSDecimalNumber(decimal: summary.expense).doubleValue)
                            )
                            .foregroundStyle(by: .value("Tipo", "Gastos"))
                            .position(by: .value("Tipo", "Gastos"))
                        }
                        .chartForegroundStyleScale([
                            "Ingresos": Color.green,
                            "Gastos": Color.red
                        ])
                        .frame(height: 200)
                    }
                }

                if !holdings.isEmpty {
                    Section("Inversiones") {
                        LabeledContent("Valor actual") {
                            Text(totalInvestmentValue, format: .currency(code: "EUR"))
                        }
                        LabeledContent("Invertido") {
                            Text(totalInvestmentCost, format: .currency(code: "EUR"))
                        }
                        if let totalGainLossPercent {
                            LabeledContent("Rentabilidad") {
                                HStack(spacing: 4) {
                                    Text(totalGainLoss, format: .currency(code: "EUR").sign(strategy: .always()))
                                    Text("(\(totalGainLossPercent, format: .percent.precision(.fractionLength(1))))")
                                }
                                .foregroundStyle(totalGainLoss >= 0 ? Color.green : Color.red)
                            }
                        }

                        ForEach(holdings) { holding in
                            NavigationLink {
                                HoldingDetailView(holding: holding)
                            } label: {
                                DashboardHoldingRow(holding: holding)
                            }
                        }
                    }
                }

                if !spendByCategory.isEmpty {
                    Section("Gasto por categoría") {
                        Chart(spendByCategory, id: \.category) { item in
                            BarMark(
                                x: .value("Importe", NSDecimalNumber(decimal: item.total).doubleValue),
                                y: .value("Categoría", item.category)
                            )
                        }
                        .frame(height: CGFloat(spendByCategory.count) * 32 + 20)
                    }
                }

                if !recentTransactions.isEmpty {
                    Section("Movimientos recientes") {
                        ForEach(recentTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                    }
                }

                if accounts.isEmpty && transactions.isEmpty {
                    ContentUnavailableView(
                        "Empieza a registrar tus finanzas",
                        systemImage: "chart.pie",
                        description: Text("Añade una cuenta y tus primeros movimientos desde las pestañas de abajo.")
                    )
                }
            }
            .navigationTitle("Resumen")
        }
    }
}

private struct DashboardHoldingRow: View {
    let holding: Holding

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(holding.ticker)
                    .font(.subheadline.bold())
                Text(holding.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(holding.marketValue ?? holding.totalCost, format: .currency(code: holding.currency))
                    .font(.caption)
                if let gainLoss = holding.gainLoss, let percent = holding.gainLossPercent {
                    HStack(spacing: 2) {
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
    DashboardView()
        .modelContainer(PreviewData.container)
}
