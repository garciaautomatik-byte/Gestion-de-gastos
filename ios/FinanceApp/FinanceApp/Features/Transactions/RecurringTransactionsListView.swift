import SwiftUI
import SwiftData

// No NavigationStack of its own: this view is pushed via NavigationLink from
// TransactionsListView, so it relies on the parent's navigation bar.
struct RecurringTransactionsListView: View {
    @Query(sort: \RecurringTransaction.dayOfMonth) private var rules: [RecurringTransaction]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddRule = false
    @State private var editingRule: RecurringTransaction?

    var body: some View {
        List {
            ForEach(rules) { rule in
                RecurringTransactionRow(rule: rule) {
                    editingRule = rule
                }
            }
            .onDelete(perform: deleteRules)
        }
        .navigationTitle("Recurrentes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddRule = true
                } label: {
                    Label("Añadir", systemImage: "plus")
                }
            }
        }
        .overlay {
            if rules.isEmpty {
                ContentUnavailableView(
                    "Sin movimientos recurrentes",
                    systemImage: "repeat",
                    description: Text("Añade gastos o ingresos que se repitan cada mes, como la nómina o el alquiler.")
                )
            }
        }
        .sheet(isPresented: $showingAddRule) {
            AddRecurringTransactionView()
        }
        .sheet(item: $editingRule) { rule in
            AddRecurringTransactionView(existingRule: rule)
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
    }
}

private struct RecurringTransactionRow: View {
    @Bindable var rule: RecurringTransaction
    var onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(rule.transactionDescription)
                    .font(.headline)
                    .strikethrough(!rule.isActive)
                    .foregroundStyle(rule.isActive ? .primary : .secondary)
                Text("Día \(rule.dayOfMonth) · \(rule.account?.name ?? "Sin cuenta")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(rule.signedAmount, format: .currency(code: rule.currency).sign(strategy: .always()))
                    .foregroundStyle(rule.kind == .expense ? Color.red : Color.green)
                Toggle("Activo", isOn: $rule.isActive)
                    .labelsHidden()
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecurringTransactionsListView()
    }
    .modelContainer(PreviewData.container)
}
