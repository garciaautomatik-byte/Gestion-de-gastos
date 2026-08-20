import SwiftUI
import SwiftData

private enum StatsKind: String, CaseIterable, Identifiable {
    case income, expense

    var id: String { rawValue }

    var label: String {
        switch self {
        case .income: return "Ingresos"
        case .expense: return "Gastos"
        }
    }

    var tint: Color {
        switch self {
        case .income: return .green
        case .expense: return .red
        }
    }
}

private enum PeriodGranularity: String, CaseIterable, Identifiable {
    case day, week, month, year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "Día"
        case .week: return "Semana"
        case .month: return "Mes"
        case .year: return "Año"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

private enum MovementsCategoryFilter: Equatable {
    case all
    case uncategorized
    case specific(Category)

    var label: String {
        switch self {
        case .all: return "Todas las categorías"
        case .uncategorized: return "Sin categoría"
        case .specific(let category): return category.name
        }
    }
}

/// Combines the period/kind breakdown ("Estadísticas") with the underlying movement list and
/// its actions (add, filter by category, recurring) — one screen instead of two, per the user's
/// request to merge what used to be separate "Movimientos" and "Estadísticas" destinations.
struct StatisticsView: View {
    /// When presented modally (from Cuentas), shows a "Cerrar" button; when embedded as the
    /// Movimientos tab root, there's nothing to dismiss to, so the button is hidden.
    var embedded: Bool = false

    @Query(sort: \MoneyTransaction.date, order: .reverse) private var allTransactions: [MoneyTransaction]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKind: StatsKind = .income
    @State private var selectedGranularity: PeriodGranularity = .month
    @State private var referenceDate: Date = .now
    @State private var categoryFilter: MovementsCategoryFilter = .all
    @State private var showingAddTransaction = false
    @State private var showingAddTransfer = false
    @State private var showingAddRecurring = false
    @State private var editingTransaction: MoneyTransaction?
    @Namespace private var kindPillNamespace

    private let calendar = Calendar.current

    private var currentRange: DateInterval {
        calendar.dateInterval(of: selectedGranularity.calendarComponent, for: referenceDate)
            ?? DateInterval(start: referenceDate, duration: 0)
    }

    private var previousRange: DateInterval {
        let previousReference = calendar.date(byAdding: selectedGranularity.calendarComponent, value: -1, to: referenceDate) ?? referenceDate
        return calendar.dateInterval(of: selectedGranularity.calendarComponent, for: previousReference)
            ?? DateInterval(start: previousReference, duration: 0)
    }

    private var isNextDisabled: Bool {
        let nextReference = calendar.date(byAdding: selectedGranularity.calendarComponent, value: 1, to: referenceDate) ?? referenceDate
        let nextRange = calendar.dateInterval(of: selectedGranularity.calendarComponent, for: nextReference)
        return (nextRange?.start ?? nextReference) > .now
    }

    private func transactionsInRange(_ range: DateInterval) -> [MoneyTransaction] {
        allTransactions.filter { !$0.isTransfer && range.contains($0.date) }
    }

    private func income(in range: DateInterval) -> Decimal {
        transactionsInRange(range).filter { $0.amount > 0 }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func expense(in range: DateInterval) -> Decimal {
        abs(transactionsInRange(range).filter { $0.amount < 0 }.reduce(Decimal(0)) { $0 + $1.amount })
    }

    private var currentTransactions: [MoneyTransaction] { transactionsInRange(currentRange) }
    private var currentIncome: Decimal { income(in: currentRange) }
    private var currentExpense: Decimal { expense(in: currentRange) }
    private var currentBalance: Decimal { currentIncome - currentExpense }

    private var headlineAmount: Decimal {
        selectedKind == .income ? currentIncome : currentExpense
    }

    private var deltaAmount: Decimal {
        let previous = selectedKind == .income ? income(in: previousRange) : expense(in: previousRange)
        return headlineAmount - previous
    }

    private var periodLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        switch selectedGranularity {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        case .week:
            let weekOfYear = calendar.component(.weekOfYear, from: referenceDate)
            let year = calendar.component(.yearForWeekOfYear, from: referenceDate)
            return "Semana \(weekOfYear) de \(year)"
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("yyyy")
        }
        return formatter.string(from: referenceDate).capitalized
    }

    /// The movements that make up "Resumen del periodo" — everything in the selected period,
    /// regardless of the Ingresos/Gastos toggle above (that toggle only changes the headline),
    /// optionally narrowed further by category.
    private var displayedTransactions: [MoneyTransaction] {
        switch categoryFilter {
        case .all: return currentTransactions
        case .uncategorized: return currentTransactions.filter { $0.category == nil }
        case .specific(let category): return currentTransactions.filter { $0.category?.id == category.id }
        }
    }

    private var availableCategories: [Category] {
        Set(currentTransactions.compactMap { $0.category }).sorted { $0.name < $1.name }
    }

    private var hasUncategorized: Bool {
        currentTransactions.contains { $0.category == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                        .padding(.top, 12)
                    granularityPicker
                        .padding(.top, 4)
                    monthNavigator
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section("Resumen del periodo") {
                    periodSummaryGrid
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 12, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section("Movimientos") {
                    if displayedTransactions.isEmpty {
                        Text("Sin movimientos en este periodo")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(displayedTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .contentShape(Rectangle())
                                .onTapGesture { editingTransaction = transaction }
                        }
                        .onDelete(perform: deleteTransactions)
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                .listRowBackground(Color.appCard)
            }
            .listStyle(.plain)
            .navigationBarTitleDisplayMode(.inline)
            .themedListBackground()
            .toolbar {
                if embedded {
                    ToolbarItem(placement: .topBarLeading) {
                        categoryFilterMenu
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            RecurringTransactionsListView()
                        } label: {
                            Label("Recurrentes", systemImage: "repeat")
                        }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        categoryFilterMenu
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddTransaction = true
                        } label: {
                            Label("Nuevo movimiento", systemImage: "plus.circle")
                        }
                        Button {
                            showingAddTransfer = true
                        } label: {
                            Label("Transferencia entre cuentas", systemImage: "arrow.left.arrow.right")
                        }
                        Button {
                            showingAddRecurring = true
                        } label: {
                            Label("Gasto o ingreso recurrente", systemImage: "repeat")
                        }
                    } label: {
                        Label("Añadir", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
            .sheet(isPresented: $showingAddTransfer) {
                AddTransferView()
            }
            .sheet(isPresented: $showingAddRecurring) {
                AddRecurringTransactionView()
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionView(existingTransaction: transaction)
            }
        }
    }

    private var categoryFilterMenu: some View {
        Menu {
            Button {
                categoryFilter = .all
            } label: {
                if categoryFilter == .all {
                    Label("Todas las categorías", systemImage: "checkmark")
                } else {
                    Text("Todas las categorías")
                }
            }
            if hasUncategorized {
                Button {
                    categoryFilter = .uncategorized
                } label: {
                    if categoryFilter == .uncategorized {
                        Label("Sin categoría", systemImage: "checkmark")
                    } else {
                        Text("Sin categoría")
                    }
                }
            }
            ForEach(availableCategories) { category in
                Button {
                    categoryFilter = .specific(category)
                } label: {
                    if categoryFilter == .specific(category) {
                        Label(category.name, systemImage: "checkmark")
                    } else {
                        Text(category.name)
                    }
                }
            }
        } label: {
            Label("Categoría", systemImage: categoryFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let transaction = displayedTransactions[index]
            delete(transaction)
            if transaction.isTransfer, let pairID = transaction.transferPairID {
                let pairedLegs = allTransactions.filter { $0.transferPairID == pairID && $0.id != transaction.id }
                for leg in pairedLegs { delete(leg) }
            }
        }
    }

    private func delete(_ transaction: MoneyTransaction) {
        if let account = transaction.account {
            account.currentBalance -= transaction.amount
        }
        modelContext.delete(transaction)
    }

    private var summaryCard: some View {
        let tint = selectedKind.tint

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(StatsKind.allCases) { kind in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedKind = kind }
                    } label: {
                        Text(kind.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedKind == kind ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if selectedKind == kind {
                                    Capsule()
                                        .fill(kind.tint)
                                        .matchedGeometryEffect(id: "kindPill", in: kindPillNamespace)
                                }
                            }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(4)
            .background(Color.appCardSecondary, in: Capsule())

            VStack(alignment: .leading, spacing: 6) {
                Text(selectedKind.label.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(headlineAmount, format: .currency(code: "EUR"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                HStack(spacing: 8) {
                    Text(deltaAmount, format: .currency(code: "EUR").sign(strategy: .always()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.15), in: Capsule())
                        .contentTransition(.numericText())
                    Text("vs. periodo anterior")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [tint.opacity(0.14), tint.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(tint.opacity(0.3))
        }
        .shadow(color: tint.opacity(0.18), radius: 20, x: 0, y: 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedKind)
        .padding(.horizontal, 20)
    }

    private var granularityPicker: some View {
        Picker("Periodo", selection: $selectedGranularity) {
            ForEach(PeriodGranularity.allCases) { granularity in
                Text(granularity.label).tag(granularity)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedGranularity) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                referenceDate = .now
            }
        }
        .padding(.horizontal, 20)
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    referenceDate = calendar.date(byAdding: selectedGranularity.calendarComponent, value: -1, to: referenceDate) ?? referenceDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background(Color.appCardSecondary, in: Circle())
            }
            .buttonStyle(PressableButtonStyle())

            Spacer()

            Text(periodLabel)
                .font(.subheadline.weight(.semibold))
                .id(periodLabel)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    referenceDate = calendar.date(byAdding: selectedGranularity.calendarComponent, value: 1, to: referenceDate) ?? referenceDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background(Color.appCardSecondary, in: Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isNextDisabled)
            .opacity(isNextDisabled ? 0.4 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.appCard, in: Capsule())
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var periodSummaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(title: "Ingresos", valueText: currentIncome.formatted(.currency(code: "EUR")), icon: "arrow.up.right", tint: .green)
            StatTile(title: "Gastos", valueText: currentExpense.formatted(.currency(code: "EUR")), icon: "arrow.down.right", tint: .red)
            StatTile(title: "Balance", valueText: currentBalance.formatted(.currency(code: "EUR").sign(strategy: .always())), icon: "arrow.up.arrow.down", tint: .accentColor)
            StatTile(title: "Transacciones", valueText: "\(currentTransactions.count)", icon: "doc.text.fill", tint: .secondary)
        }
    }
}

private struct StatTile: View {
    let title: String
    let valueText: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle().fill(tint.opacity(0.15))
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(valueText)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .overlay(alignment: .leading) {
            Rectangle().fill(tint).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(PreviewData.container)
}
