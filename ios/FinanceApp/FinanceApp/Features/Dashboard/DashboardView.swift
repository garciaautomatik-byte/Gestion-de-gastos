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

    @State private var widgetOrder: [DashboardWidget] = DashboardWidget.allCases
    @State private var hiddenWidgets: Set<DashboardWidget> = []
    @State private var showingCustomize = false
    @State private var selectedMonth: String?

    private var visibleWidgets: [DashboardWidget] {
        widgetOrder.filter { !hiddenWidgets.contains($0) }
    }

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

    private var maxCategoryTotal: Decimal {
        spendByCategory.map(\.total).max() ?? 0
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

    private var selectedSummary: MonthlySummary? {
        guard let selectedMonth else { return nil }
        return monthlySummaries.first { $0.label == selectedMonth }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleWidgets) { widget in
                    widgetSection(for: widget)
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingCustomize = true
                    } label: {
                        Label("Personalizar", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .onAppear(perform: loadLayout)
            .sheet(isPresented: $showingCustomize, onDismiss: saveLayout) {
                DashboardCustomizeView(order: $widgetOrder, hidden: $hiddenWidgets)
            }
        }
    }

    @ViewBuilder
    private func widgetSection(for widget: DashboardWidget) -> some View {
        switch widget {
        case .balance:
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

        case .monthlyChart:
            if monthlySummaries.contains(where: { $0.income > 0 || $0.expense > 0 }) {
                Section("Ingresos y gastos por mes") {
                    Chart(monthlySummaries) { summary in
                        BarMark(
                            x: .value("Mes", summary.label),
                            y: .value("Importe", NSDecimalNumber(decimal: summary.income).doubleValue)
                        )
                        .foregroundStyle(by: .value("Tipo", "Ingresos"))
                        .position(by: .value("Tipo", "Ingresos"))
                        .cornerRadius(6)

                        BarMark(
                            x: .value("Mes", summary.label),
                            y: .value("Importe", NSDecimalNumber(decimal: summary.expense).doubleValue)
                        )
                        .foregroundStyle(by: .value("Tipo", "Gastos"))
                        .position(by: .value("Tipo", "Gastos"))
                        .cornerRadius(6)

                        if selectedMonth == summary.label {
                            RuleMark(x: .value("Mes", summary.label))
                                .foregroundStyle(.gray.opacity(0.25))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        }
                    }
                    .chartForegroundStyleScale([
                        "Ingresos": Color.green,
                        "Gastos": Color.red
                    ])
                    .chartLegend(position: .top, alignment: .leading, spacing: 8)
                    .chartXSelection(value: $selectedMonth)
                    .frame(height: 200)
                    .padding(.vertical, 4)

                    if let selectedSummary {
                        HStack(spacing: 16) {
                            Label {
                                Text(selectedSummary.income, format: .currency(code: "EUR"))
                            } icon: {
                                Image(systemName: "arrow.up.circle.fill")
                            }
                            .foregroundStyle(Color.green)

                            Label {
                                Text(selectedSummary.expense, format: .currency(code: "EUR"))
                            } icon: {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            .foregroundStyle(Color.red)
                        }
                        .font(.subheadline.bold())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Text("Toca una barra para ver el importe exacto de ese mes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        case .investments:
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

        case .categorySpending:
            if !spendByCategory.isEmpty {
                Section("Gasto por categoría") {
                    ForEach(spendByCategory, id: \.category) { item in
                        CategorySpendRow(category: item.category, total: item.total, maxTotal: maxCategoryTotal)
                    }
                }
            }

        case .recentTransactions:
            if !recentTransactions.isEmpty {
                Section("Movimientos recientes") {
                    ForEach(recentTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }

    private func loadLayout() {
        let (order, hidden) = DashboardLayoutStore.load()
        widgetOrder = order
        hiddenWidgets = hidden
    }

    private func saveLayout() {
        DashboardLayoutStore.save(order: widgetOrder, hidden: hiddenWidgets)
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

private struct CategorySpendRow: View {
    let category: String
    let total: Decimal
    let maxTotal: Decimal

    private var proportion: Double {
        guard maxTotal > 0 else { return 0 }
        return max(0, min(1, NSDecimalNumber(decimal: total / maxTotal).doubleValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category)
                Spacer()
                Text(total, format: .currency(code: "EUR"))
            }
            .font(.body)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.orange.opacity(0.15))
                    Capsule()
                        .fill(Color.orange)
                        .frame(width: geo.size.width * proportion)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView()
        .modelContainer(PreviewData.container)
}
