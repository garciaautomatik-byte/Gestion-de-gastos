import SwiftUI
import SwiftData

private enum AccountMovementFilter: String, CaseIterable, Identifiable {
    case all, income, expense

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Todo"
        case .income: return "Ingresos"
        case .expense: return "Gastos"
        }
    }
}

struct AccountDetailView: View {
    let account: Account
    @Query(sort: \MoneyTransaction.date) private var allTransactions: [MoneyTransaction]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var filter: AccountMovementFilter = .all
    @State private var showingAdjustBalance = false
    @State private var showingTransfer = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var editingTransaction: MoneyTransaction?

    private var sortedTransactions: [MoneyTransaction] {
        account.transactions.sorted { $0.date > $1.date }
    }

    private var filteredTransactions: [MoneyTransaction] {
        switch filter {
        case .all: return sortedTransactions
        case .income: return sortedTransactions.filter { $0.amount > 0 }
        case .expense: return sortedTransactions.filter { $0.amount < 0 }
        }
    }

    var body: some View {
        List {
            Section {
                AccountHeaderCard(account: account)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                HStack(spacing: 10) {
                    AccountActionButton(title: "Ajustar", icon: "slider.horizontal.3") {
                        showingAdjustBalance = true
                    }
                    AccountActionButton(title: "Transferir", icon: "arrow.left.arrow.right") {
                        showingTransfer = true
                    }
                    AccountActionButton(title: "Editar", icon: "pencil") {
                        showingEdit = true
                    }
                    AccountActionButton(title: "Eliminar", icon: "trash", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.bottom, 4)
            }

            Section {
                Picker("Filtro", selection: $filter) {
                    ForEach(AccountMovementFilter.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.appCard)
            }

            Section("Movimientos") {
                if filteredTransactions.isEmpty {
                    Text("Sin movimientos")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !transaction.isTransfer {
                                    editingTransaction = transaction
                                }
                            }
                    }
                    .onDelete(perform: deleteTransactions)
                }
            }
            .listRowBackground(Color.appCard)
        }
        .navigationTitle(account.name)
        .themedListBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTransaction) { transaction in
            AddTransactionView(existingTransaction: transaction)
        }
        .sheet(isPresented: $showingAdjustBalance) {
            AdjustBalanceView(account: account)
        }
        .sheet(isPresented: $showingTransfer) {
            AddTransferView(preselectedSourceAccount: account)
        }
        .sheet(isPresented: $showingEdit) {
            EditAccountView(account: account)
        }
        .confirmationDialog(
            "¿Eliminar \(account.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                modelContext.delete(account)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrarán también todos sus movimientos, transferencias e inversiones asociadas.")
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let transaction = filteredTransactions[index]
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
}

private struct AccountHeaderCard: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(account.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                Text(account.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }
            Text(account.currentBalance, format: .currency(code: account.currency))
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(account.currency)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: account.colorHex), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.vertical, 4)
    }
}

struct AccountActionButton: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    var role: ButtonRole?
    let action: () -> Void

    private var tint: Color { role == .destructive ? .red : .accentColor }

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(tint.opacity(0.16))
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 32, height: 32)

                VStack(spacing: 1) {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, subtitle == nil ? 10 : 14)
            .background(Color.appCardSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let container = PreviewData.container
    let account = try! container.mainContext.fetch(FetchDescriptor<Account>()).first!
    return NavigationStack {
        AccountDetailView(account: account)
    }
    .modelContainer(container)
}
