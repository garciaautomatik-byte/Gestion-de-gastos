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
    @State private var repeatsMonthly = false
    @State private var showingDatePicker = false
    @State private var showingAddCategory = false
    @State private var showingCategorySearch = false
    @State private var categorySearchText = ""
    @FocusState private var amountFieldFocused: Bool
    @Namespace private var kindNamespace

    init(existingTransaction: MoneyTransaction? = nil, defaultKind: CategoryKind = .expense) {
        self.existingTransaction = existingTransaction
        _selectedAccount = State(initialValue: existingTransaction?.account)
        _selectedCategory = State(initialValue: existingTransaction?.category)
        _descriptionText = State(initialValue: existingTransaction?.transactionDescription ?? "")
        _amountText = State(initialValue: existingTransaction.map { NSDecimalNumber(decimal: abs($0.amount)).stringValue } ?? "")
        _date = State(initialValue: existingTransaction?.date ?? .now)
        _kind = State(initialValue: existingTransaction.map { $0.amount < 0 ? .expense : .income } ?? defaultKind)
    }

    private var filteredCategories: [Category] {
        let base = categories.filter { $0.kind == kind && (!$0.isHidden || $0.id == selectedCategory?.id) }
        guard !categorySearchText.trimmingCharacters(in: .whitespaces).isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(categorySearchText) }
    }

    private var eligibleAccounts: [Account] {
        accounts.filter { $0.type != .investmentManual }
    }

    private var kindTint: Color {
        kind == .expense ? .red : .green
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    if existingTransaction != nil {
                        Text("Editando movimiento")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    kindPicker
                    amountEntry
                    fechaRepetirRow
                    accountSection
                    categorySection
                    notesField
                }
                .padding(.top, 28)
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)

            closeButton
        }
        .safeAreaInset(edge: .bottom) {
            saveButton
        }
        .onChange(of: kind) {
            selectedCategory = nil
        }
        .onAppear {
            if selectedAccount == nil {
                selectedAccount = eligibleAccounts.first
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $showingAddCategory) {
            AddEditCategoryView(defaultKind: kind)
        }
    }

    // MARK: - Sections

    private var kindPicker: some View {
        HStack(spacing: 4) {
            ForEach([CategoryKind.expense, .income], id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { kind = option }
                } label: {
                    Text(option == .expense ? "Gasto" : "Ingreso")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(kind == option ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if kind == option {
                                Capsule()
                                    .fill(.white)
                                    .matchedGeometryEffect(id: "kindSegment", in: kindNamespace)
                            }
                        }
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(4)
        .background(Color.appCard, in: Capsule())
    }

    private var amountEntry: some View {
        VStack(spacing: 6) {
            Text("CANTIDAD")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0,00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(amountText.isEmpty ? Color.primary : kindTint)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .focused($amountFieldFocused)
                    .animation(.easeOut(duration: 0.15), value: kind)
                Text("€")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { amountFieldFocused = true }
    }

    private var fechaRepetirRow: some View {
        HStack(spacing: 12) {
            Button {
                showingDatePicker = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.green.opacity(0.15))
                        Image(systemName: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("FECHA")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(date, format: .dateTime.day().month(.abbreviated).year())
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())

            HStack(spacing: 8) {
                Image(systemName: "repeat")
                    .font(.subheadline)
                    .foregroundStyle(.green)

                Text("Repetir")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Toggle("", isOn: $repeatsMonthly.animation(.easeOut(duration: 0.15)))
                    .labelsHidden()
                    .tint(.green)
                    .scaleEffect(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CUENTA")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(eligibleAccounts) { account in
                        AccountPickerCard(account: account, isSelected: selectedAccount?.id == account.id) {
                            withAnimation(.easeOut(duration: 0.15)) { selectedAccount = account }
                        }
                    }
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CATEGORÍA")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showingCategorySearch.toggle()
                        if !showingCategorySearch { categorySearchText = "" }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PressableButtonStyle())
            }

            if showingCategorySearch {
                TextField("Buscar categoría", text: $categorySearchText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                Button {
                    showingAddCategory = true
                } label: {
                    CategoryCellContent(icon: "plus", tint: .green, name: "Nueva", isNew: true, isSelected: false)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.94))

                ForEach(filteredCategories) { category in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selectedCategory = category }
                    } label: {
                        CategoryCellContent(
                            icon: category.icon,
                            tint: Color(hex: category.colorHex),
                            name: category.name,
                            isNew: false,
                            isSelected: selectedCategory?.id == category.id
                        )
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.94))
                }
            }
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTAS (OPCIONAL)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            TextField("Añade una descripción...", text: $descriptionText)
                .textFieldStyle(.plain)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.appCardSecondary).frame(height: 1)
                }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Guardar movimiento")
                .font(.headline)
                .foregroundStyle(isValid ? .black : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValid ? Color.green : Color.appCard, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isValid)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.appCard, in: Circle())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("Fecha", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Fecha")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") { showingDatePicker = false }
                    }
                }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Save

    private var isValid: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        return selectedAccount != nil
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var effectiveDescription: String {
        let trimmed = descriptionText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return selectedCategory?.name ?? (kind == .expense ? "Gasto" : "Ingreso")
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
            existingTransaction.transactionDescription = effectiveDescription
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
                transactionDescription: effectiveDescription,
                source: .manual,
                account: selectedAccount,
                category: selectedCategory
            )
            modelContext.insert(transaction)

            if let account = selectedAccount {
                account.currentBalance += signedAmount
            }

            if repeatsMonthly, let account = selectedAccount {
                let rule = RecurringTransaction(
                    transactionDescription: effectiveDescription,
                    amount: abs(rawAmount),
                    currency: account.currency,
                    kind: kind,
                    dayOfMonth: Calendar.current.component(.day, from: date),
                    account: account,
                    category: selectedCategory
                )
                modelContext.insert(rule)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct AccountPickerCard: View {
    let account: Account
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                BankLogoView(name: account.name, fallbackColor: Color(hex: account.colorHex), diameter: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(account.currentBalance, format: .currency(code: account.currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(width: 140, alignment: .leading)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
    }
}

private struct CategoryCellContent: View {
    let icon: String
    let tint: Color
    let name: String
    let isNew: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isNew ? Color.clear : tint.opacity(0.18))
                    .overlay {
                        Circle().strokeBorder(
                            isNew ? tint : (isSelected ? tint : .clear),
                            style: StrokeStyle(lineWidth: 2, dash: isNew ? [5, 4] : [])
                        )
                    }
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 52, height: 52)

            Text(name)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(PreviewData.container)
}
