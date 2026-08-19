import SwiftUI
import SwiftData

private struct MonthPeriod: Hashable, Identifiable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)" }

    private var date: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month)) ?? .now
    }

    var label: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date).capitalized
    }
}

private enum CategoryFilter: Equatable {
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

struct TransactionsListView: View {
    @Query(sort: \MoneyTransaction.date, order: .reverse) private var transactions: [MoneyTransaction]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddTransaction = false
    @State private var showingAddTransfer = false
    @State private var showingAddRecurring = false
    @State private var selectedPeriod: MonthPeriod?
    @State private var selectedCategoryFilter: CategoryFilter = .all
    @State private var editingTransaction: MoneyTransaction?

    private var isFiltering: Bool {
        selectedPeriod != nil || selectedCategoryFilter != .all
    }

    private var availablePeriods: [MonthPeriod] {
        let calendar = Calendar.current
        let periods = Set(transactions.map { tx -> MonthPeriod in
            let comps = calendar.dateComponents([.year, .month], from: tx.date)
            return MonthPeriod(year: comps.year ?? 0, month: comps.month ?? 0)
        })
        return periods.sorted { $0.year != $1.year ? $0.year > $1.year : $0.month > $1.month }
    }

    private var availableCategories: [Category] {
        Set(transactions.compactMap { $0.category }).sorted { $0.name < $1.name }
    }

    private var hasUncategorizedTransactions: Bool {
        transactions.contains { $0.category == nil }
    }

    private var filteredTransactions: [MoneyTransaction] {
        var result = transactions

        if let selectedPeriod {
            let calendar = Calendar.current
            result = result.filter { tx in
                let comps = calendar.dateComponents([.year, .month], from: tx.date)
                return comps.year == selectedPeriod.year && comps.month == selectedPeriod.month
            }
        }

        switch selectedCategoryFilter {
        case .all:
            break
        case .uncategorized:
            result = result.filter { $0.category == nil }
        case .specific(let category):
            result = result.filter { $0.category?.id == category.id }
        }

        return result
    }

    private var filterSummaryTitle: String {
        var parts: [String] = []
        if let selectedPeriod { parts.append(selectedPeriod.label) }
        if selectedCategoryFilter != .all { parts.append(selectedCategoryFilter.label) }
        return parts.joined(separator: " · ")
    }

    private var periodIncome: Decimal {
        filteredTransactions.filter { $0.amount > 0 && !$0.isTransfer }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var periodExpense: Decimal {
        filteredTransactions.filter { $0.amount < 0 && !$0.isTransfer }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                if isFiltering {
                    Section(filterSummaryTitle) {
                        LabeledContent("Ingresos") {
                            Text(periodIncome, format: .currency(code: "EUR"))
                                .foregroundStyle(Color.green)
                        }
                        LabeledContent("Gastos") {
                            Text(abs(periodExpense), format: .currency(code: "EUR"))
                                .foregroundStyle(Color.red)
                        }
                        LabeledContent("Balance") {
                            Text(periodIncome + periodExpense, format: .currency(code: "EUR").sign(strategy: .always()))
                        }
                    }
                }

                ForEach(filteredTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Transfers have two linked legs with their own invariants (equal
                            // and opposite amounts, shared pair ID) — not editable through the
                            // generic single-transaction form.
                            if !transaction.isTransfer {
                                editingTransaction = transaction
                            }
                        }
                }
                .onDelete(perform: deleteTransactions)
            }
            .navigationTitle("Movimientos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Menu {
                            Button {
                                selectedPeriod = nil
                            } label: {
                                if selectedPeriod == nil {
                                    Label("Todos los meses", systemImage: "checkmark")
                                } else {
                                    Text("Todos los meses")
                                }
                            }
                            ForEach(availablePeriods) { period in
                                Button {
                                    selectedPeriod = period
                                } label: {
                                    if selectedPeriod == period {
                                        Label(period.label, systemImage: "checkmark")
                                    } else {
                                        Text(period.label)
                                    }
                                }
                            }
                        } label: {
                            Label("Mes", systemImage: "calendar")
                        }

                        Menu {
                            Button {
                                selectedCategoryFilter = .all
                            } label: {
                                if selectedCategoryFilter == .all {
                                    Label("Todas las categorías", systemImage: "checkmark")
                                } else {
                                    Text("Todas las categorías")
                                }
                            }
                            if hasUncategorizedTransactions {
                                Button {
                                    selectedCategoryFilter = .uncategorized
                                } label: {
                                    if selectedCategoryFilter == .uncategorized {
                                        Label("Sin categoría", systemImage: "checkmark")
                                    } else {
                                        Text("Sin categoría")
                                    }
                                }
                            }
                            ForEach(availableCategories) { category in
                                Button {
                                    selectedCategoryFilter = .specific(category)
                                } label: {
                                    if selectedCategoryFilter == .specific(category) {
                                        Label(category.name, systemImage: "checkmark")
                                    } else {
                                        Text(category.name)
                                    }
                                }
                            }
                        } label: {
                            Label("Categoría", systemImage: "tag")
                        }

                        if isFiltering {
                            Button(role: .destructive) {
                                selectedPeriod = nil
                                selectedCategoryFilter = .all
                            } label: {
                                Label("Quitar filtros", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Label("Filtrar", systemImage: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        RecurringTransactionsListView()
                    } label: {
                        Label("Recurrentes", systemImage: "repeat")
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
            .overlay {
                if filteredTransactions.isEmpty {
                    ContentUnavailableView(
                        isFiltering ? "Sin movimientos con estos filtros" : "Sin movimientos",
                        systemImage: "list.bullet",
                        description: Text(isFiltering ? "Prueba a cambiar los filtros." : "Añade tu primer movimiento con el botón +")
                    )
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

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let transaction = filteredTransactions[index]
            delete(transaction)

            // A transfer has two legs (outgoing + incoming); delete and revert both together
            // so the accounts don't end up out of sync. Searched in the unfiltered list since
            // the paired leg could fall outside the current filters.
            if transaction.isTransfer, let pairID = transaction.transferPairID {
                let pairedLegs = transactions.filter { $0.transferPairID == pairID && $0.id != transaction.id }
                for leg in pairedLegs {
                    delete(leg)
                }
            }
        }
    }

    private func delete(_ transaction: MoneyTransaction) {
        if let account = transaction.account {
            account.currentBalance -= transaction.amount
        }
        modelContext.delete(transaction)
    }
}

#Preview {
    TransactionsListView()
        .modelContainer(PreviewData.container)
}
