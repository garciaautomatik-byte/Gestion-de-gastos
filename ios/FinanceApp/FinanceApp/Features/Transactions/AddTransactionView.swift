import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Category.name) private var categories: [Category]

    private var existingTransaction: MoneyTransaction?

    @State private var selectedAccount: Account?
    @State private var selectedCategory: Category?
    @State private var descriptionText: String
    @State private var amountText: String
    @State private var date: Date
    @State private var kind: CategoryKind

    init(existingTransaction: MoneyTransaction? = nil) {
        self.existingTransaction = existingTransaction
        _selectedAccount = State(initialValue: existingTransaction?.account)
        _selectedCategory = State(initialValue: existingTransaction?.category)
        _descriptionText = State(initialValue: existingTransaction?.transactionDescription ?? "")
        _amountText = State(initialValue: existingTransaction.map { NSDecimalNumber(decimal: abs($0.amount)).stringValue } ?? "")
        _date = State(initialValue: existingTransaction?.date ?? .now)
        _kind = State(initialValue: existingTransaction.map { $0.amount < 0 ? .expense : .income } ?? .expense)
    }

    private var filteredCategories: [Category] {
        categories.filter { $0.kind == kind }
    }

    private var eligibleAccounts: [Account] {
        accounts.filter { $0.type != .investmentManual }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $kind) {
                        Text("Gasto").tag(CategoryKind.expense)
                        Text("Ingreso").tag(CategoryKind.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Detalles") {
                    TextField("Descripción", text: $descriptionText)
                    TextField("Importe", text: $amountText)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }

                Section("Cuenta") {
                    Picker("Cuenta", selection: $selectedAccount) {
                        Text("Ninguna").tag(Account?.none)
                        ForEach(eligibleAccounts) { account in
                            Text(account.name).tag(Account?.some(account))
                        }
                    }
                }

                Section("Categoría") {
                    Picker("Categoría", selection: $selectedCategory) {
                        Text("Sin categoría").tag(Category?.none)
                        ForEach(filteredCategories) { category in
                            Text(category.name).tag(Category?.some(category))
                        }
                    }
                }
            }
            .navigationTitle(existingTransaction == nil ? "Nuevo movimiento" : "Editar movimiento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!isValid)
                }
            }
            .onChange(of: kind) {
                selectedCategory = nil
            }
        }
    }

    private var isValid: Bool {
        !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty && parsedAmount != nil
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        guard let rawAmount = parsedAmount else { return }
        let signedAmount = kind == .expense ? -abs(rawAmount) : abs(rawAmount)

        if let existingTransaction {
            // Revert the old amount from whatever account it used to affect, then apply the
            // new one — handles an edit that changes the amount, the account, or both.
            if let oldAccount = existingTransaction.account {
                oldAccount.currentBalance -= existingTransaction.amount
            }
            existingTransaction.amount = signedAmount
            existingTransaction.currency = selectedAccount?.currency ?? existingTransaction.currency
            existingTransaction.date = date
            existingTransaction.transactionDescription = descriptionText
            existingTransaction.account = selectedAccount
            existingTransaction.category = selectedCategory
            if let newAccount = selectedAccount {
                newAccount.currentBalance += signedAmount
            }
        } else {
            let transaction = MoneyTransaction(
                amount: signedAmount,
                currency: selectedAccount?.currency ?? "EUR",
                date: date,
                transactionDescription: descriptionText,
                source: .manual,
                account: selectedAccount,
                category: selectedCategory
            )
            modelContext.insert(transaction)

            if let account = selectedAccount {
                account.currentBalance += signedAmount
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(PreviewData.container)
}
