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
    @State private var widgetStyles: [DashboardWidget: DashboardWidgetStyle] = [:]
    @State private var showingCustomize = false
    @State private var selectedMonth: String?
    @State private var selectedCategoryFilter: CategoryFilterSelection?
    // Always starts hidden: masked again every time this view is created (app launch, or
    // returning to the Resumen tab after the app was backgrounded and reloaded).
    @State private var isBalanceRevealed = false

    private var visibleWidgets: [DashboardWidget] {
        widgetOrder.filter { !hiddenWidgets.contains($0) }
    }

    private func style(for widget: DashboardWidget) -> DashboardWidgetStyle {
        widgetStyles[widget] ?? .detailed
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

    private func maskedAmount(_ value: Decimal) -> String {
        isBalanceRevealed ? value.formatted(.currency(code: "EUR")) : "••••••"
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
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Resumen")
            .themedListBackground()
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
                DashboardCustomizeView(order: $widgetOrder, hidden: $hiddenWidgets, styles: $widgetStyles)
            }
            .sheet(item: $selectedCategoryFilter) { selection in
                CategoryTransactionsSheet(categoryName: selection.name, transactions: transactions)
            }
        }
    }

    @ViewBuilder
    private func widgetSection(for widget: DashboardWidget) -> some View {
        switch widget {
        case .balance:
            balanceSection

        case .monthlyChart:
            if monthlySummaries.contains(where: { $0.income > 0 || $0.expense > 0 }) {
                monthlyChartSection
            }

        case .investments:
            if !holdings.isEmpty {
                investmentsSection
            }

        case .categorySpending:
            if !spendByCategory.isEmpty {
                categorySpendingSection
            }

        case .recentTransactions:
            if !recentTransactions.isEmpty {
                recentTransactionsSection
            }
        }
    }

    // MARK: - Saldo total

    @ViewBuilder
    private var balanceSection: some View {
        switch style(for: .balance) {
        case .detailed:
            Section("Saldo total") {
                HStack {
                    Text(maskedAmount(netWorth))
                        .font(.largeTitle.bold())
                    Spacer()
                    revealButton
                }

                if !holdings.isEmpty {
                    LabeledContent("Cuentas") {
                        Text(maskedAmount(totalBalance))
                    }
                    LabeledContent("Inversiones") {
                        Text(maskedAmount(totalInvestmentValue))
                    }
                }
            }
            .listRowBackground(Color.appCard)

        case .compact:
            Section {
                HStack {
                    Text("Saldo total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(maskedAmount(netWorth))
                        .font(.title3.bold())
                    revealButton
                }
            }
            .listRowBackground(Color.appCard)

        case .card:
            Section {
                WidgetStatCard(
                    title: "Saldo total",
                    value: maskedAmount(netWorth),
                    valueColor: .primary,
                    icon: isBalanceRevealed ? "eye.fill" : "eye.slash.fill",
                    tint: .blue
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation { isBalanceRevealed.toggle() }
                }
                .widgetCardRow()
            }
        }
    }

    private var revealButton: some View {
        Button {
            withAnimation { isBalanceRevealed.toggle() }
        } label: {
            Image(systemName: isBalanceRevealed ? "eye.slash" : "eye")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    // MARK: - Ingresos y gastos por mes

    @ViewBuilder
    private var monthlyChartSection: some View {
        switch style(for: .monthlyChart) {
        case .detailed:
            Section("Ingresos y gastos por mes") {
                monthlyChart(height: 200, showsLegend: true)
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
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text("Toca una barra para ver el importe exacto de ese mes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color.appCard)

        case .compact:
            Section("Ingresos y gastos por mes") {
                monthlyChart(height: 110, showsLegend: false)

                if let selectedSummary {
                    HStack {
                        Text(selectedSummary.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(selectedSummary.income, format: .currency(code: "EUR"))
                            .foregroundStyle(Color.green)
                        Text(selectedSummary.expense, format: .currency(code: "EUR"))
                            .foregroundStyle(Color.red)
                    }
                    .font(.caption)
                }
            }
            .listRowBackground(Color.appCard)

        case .card:
            Section("Ingresos y gastos por mes") {
                if let current = monthlySummaries.last {
                    HStack(spacing: 10) {
                        WidgetStatCard(
                            title: "Ingresos · \(current.label)",
                            value: current.income.formatted(.currency(code: "EUR")),
                            valueColor: .green,
                            icon: "arrow.up.circle.fill",
                            tint: .green
                        )
                        WidgetStatCard(
                            title: "Gastos · \(current.label)",
                            value: current.expense.formatted(.currency(code: "EUR")),
                            valueColor: .red,
                            icon: "arrow.down.circle.fill",
                            tint: .red
                        )
                    }
                    .widgetCardRow()
                }
            }
        }
    }

    @ViewBuilder
    private func monthlyChart(height: CGFloat, showsLegend: Bool) -> some View {
        if showsLegend {
            monthlyChartBase
                .chartLegend(position: .top, alignment: .leading, spacing: 8)
                .chartXSelection(value: $selectedMonth)
                .frame(height: height)
        } else {
            monthlyChartBase
                .chartLegend(.hidden)
                .chartXSelection(value: $selectedMonth)
                .frame(height: height)
        }
    }

    private var monthlyChartBase: some View {
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
    }

    // MARK: - Inversiones

    @ViewBuilder
    private var investmentsSection: some View {
        switch style(for: .investments) {
        case .detailed:
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
            .listRowBackground(Color.appCard)

        case .compact:
            Section("Inversiones") {
                LabeledContent("Valor actual") {
                    Text(totalInvestmentValue, format: .currency(code: "EUR"))
                }
                if let totalGainLossPercent {
                    LabeledContent("Rentabilidad") {
                        Text("\(totalGainLossPercent, format: .percent.precision(.fractionLength(1)))")
                            .foregroundStyle(totalGainLoss >= 0 ? Color.green : Color.red)
                    }
                }
            }
            .listRowBackground(Color.appCard)

        case .card:
            Section("Inversiones") {
                WidgetStatCard(
                    title: "Valor de las inversiones",
                    value: totalInvestmentValue.formatted(.currency(code: "EUR")),
                    valueColor: .primary,
                    icon: "chart.line.uptrend.xyaxis",
                    tint: .purple
                )
                .widgetCardRow()
            }
        }
    }

    // MARK: - Gasto por categoría

    @ViewBuilder
    private var categorySpendingSection: some View {
        switch style(for: .categorySpending) {
        case .detailed:
            Section("Gasto por categoría") {
                ForEach(spendByCategory, id: \.category) { item in
                    CategorySpendRow(category: item.category, total: item.total, maxTotal: maxCategoryTotal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCategoryFilter = CategoryFilterSelection(name: item.category)
                        }
                }
            }
            .listRowBackground(Color.appCard)

        case .compact:
            Section("Gasto por categoría") {
                ForEach(spendByCategory.prefix(3), id: \.category) { item in
                    HStack {
                        Text(item.category)
                        Spacer()
                        Text(item.total, format: .currency(code: "EUR"))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCategoryFilter = CategoryFilterSelection(name: item.category)
                    }
                }
            }
            .listRowBackground(Color.appCard)

        case .card:
            Section("Gasto por categoría") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(spendByCategory, id: \.category) { item in
                            WidgetChip(title: item.category, value: item.total.formatted(.currency(code: "EUR")), tint: .orange)
                                .onTapGesture {
                                    selectedCategoryFilter = CategoryFilterSelection(name: item.category)
                                }
                        }
                    }
                }
                .widgetCardRow()
            }
        }
    }

    // MARK: - Movimientos recientes

    @ViewBuilder
    private var recentTransactionsSection: some View {
        switch style(for: .recentTransactions) {
        case .detailed:
            Section("Movimientos recientes") {
                ForEach(recentTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
            .listRowBackground(Color.appCard)

        case .compact:
            Section("Movimientos recientes") {
                ForEach(recentTransactions.prefix(3)) { transaction in
                    HStack {
                        Text(transaction.merchantName ?? transaction.transactionDescription)
                            .lineLimit(1)
                        Spacer()
                        Text(transaction.amount, format: .currency(code: transaction.currency))
                            .foregroundStyle(transactionColor(transaction))
                    }
                    .font(.subheadline)
                }
            }
            .listRowBackground(Color.appCard)

        case .card:
            Section("Movimientos recientes") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentTransactions) { transaction in
                            WidgetChip(
                                title: transaction.merchantName ?? transaction.transactionDescription,
                                value: transaction.amount.formatted(.currency(code: transaction.currency)),
                                tint: transactionColor(transaction)
                            )
                        }
                    }
                }
                .widgetCardRow()
            }
        }
    }

    private func transactionColor(_ transaction: MoneyTransaction) -> Color {
        if transaction.isTransfer { return .blue }
        return transaction.amount < 0 ? .primary : .green
    }

    private func loadLayout() {
        let (order, hidden, styles) = DashboardLayoutStore.load()
        widgetOrder = order
        hiddenWidgets = hidden
        widgetStyles = styles
    }

    private func saveLayout() {
        DashboardLayoutStore.save(order: widgetOrder, hidden: hiddenWidgets, styles: widgetStyles)
    }
}

private struct CategoryFilterSelection: Identifiable {
    let name: String
    var id: String { name }
}

/// All-time expenses for one category, opened by tapping a row/chip in "Gasto por categoría" —
/// mirrors the same all-time scope that section's totals are computed with.
private struct CategoryTransactionsSheet: View {
    let categoryName: String
    let transactions: [MoneyTransaction]
    @Environment(\.dismiss) private var dismiss

    private var filtered: [MoneyTransaction] {
        transactions.filter {
            !$0.isTransfer && $0.amount < 0 && ($0.category?.name ?? "Sin categoría") == categoryName
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { transaction in
                TransactionRow(transaction: transaction)
                    .listRowBackground(Color.appCard)
            }
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .themedListBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView("Sin movimientos", systemImage: "list.bullet")
                }
            }
        }
    }
}

/// Rounded, colored stat tile shared by every widget's "Tarjeta" style.
private struct WidgetStatCard: View {
    let title: String
    let value: String
    let valueColor: Color
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Small pill used by the horizontally-scrolling "Tarjeta" style for list-like widgets.
private struct WidgetChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(10)
        .frame(minWidth: 120, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension View {
    /// Lets a widget's own rounded background float on the List's grouped background,
    /// instead of sitting inside the default white inset-grouped row.
    func widgetCardRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .padding(.vertical, 4)
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
