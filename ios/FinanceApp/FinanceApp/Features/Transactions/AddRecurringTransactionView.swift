import SwiftUI
import SwiftData

struct AddRecurringTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Category.name) private var categories: [Category]

    private var existingRule: RecurringTransaction?

    @State private var selectedAccount: Account?
    @State private var selectedCategory: Category?
    @State private var descriptionText: String
    @State private var amountText: String
    @State private var dayOfMonth: Int
    @State private var kind: CategoryKind

    init(existingRule: RecurringTransaction? = nil) {
        self.existingRule = existingRule
        _selectedAccount = State(initialValue: existingRule?.account)
        _selectedCategory = State(initialValue: existingRule?.category)
        _descriptionText = State(initialValue: existingRule?.transactionDescription ?? "")
        _amountText = State(initialValue: existingRule.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? "")
        _dayOfMonth = State(initialValue: existingRule?.dayOfMonth ?? 1)
        _kind = State(initialValue: existingRule?.kind ?? .expense)
    }

    private var filteredCategories: [Category] {
        categories.filter { $0.kind == kind && (!$0.isHidden || $0.id == selectedCategory?.id) }
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
                .listRowBackground(Color.appCard)

                Section("Detalles") {
                    TextField("Descripción", text: $descriptionText)
                    TextField("Importe", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Día del mes", selection: $dayOfMonth) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                }
                .listRowBackground(Color.appCard)

                Section("Cuenta") {
                    Picker("Cuenta", selection: $selectedAccount) {
                        Text("Selecciona una cuenta").tag(Account?.none)
                        ForEach(eligibleAccounts) { account in
                            Text(account.name).tag(Account?.some(account))
                        }
                    }
                }
                .listRowBackground(Color.appCard)

                Section("Categoría") {
                    Picker("Categoría", selection: $selectedCategory) {
                        Text("Sin categoría").tag(Category?.none)
                        ForEach(filteredCategories) { category in
                            Text(category.name).tag(Category?.some(category))
                        }
                    }
                }
                .listRowBackground(Color.appCard)

                Section {
                    Text(existingRule == nil
                        ? "Se añadirá automáticamente cada mes en este día, la próxima vez que abras la app. Este mes no se añade todavía."
                        : "Los cambios se aplicarán la próxima vez que toque generar este movimiento.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.appCard)
            }
            .navigationTitle(existingRule == nil ? "Nuevo recurrente" : "Editar recurrente")
            .themedListBackground()
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
        !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty
            && (parsedAmount.map { $0 > 0 } ?? false)
            && selectedAccount != nil
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        guard let amount = parsedAmount, let account = selectedAccount else { return }

        if let existingRule {
            existingRule.transactionDescription = descriptionText
            existingRule.amount = abs(amount)
            existingRule.currency = account.currency
            existingRule.kind = kind
            existingRule.dayOfMonth = dayOfMonth
            existingRule.account = account
            existingRule.category = selectedCategory
        } else {
            let rule = RecurringTransaction(
                transactionDescription: descriptionText,
                amount: abs(amount),
                currency: account.currency,
                kind: kind,
                dayOfMonth: dayOfMonth,
                account: account,
                category: selectedCategory
            )
            modelContext.insert(rule)
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddRecurringTransactionView()
        .modelContainer(PreviewData.container)
}
