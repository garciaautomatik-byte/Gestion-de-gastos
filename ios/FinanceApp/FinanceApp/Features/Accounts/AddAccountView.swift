import SwiftUI
import SwiftData

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: AccountType = .checking
    @State private var initialBalanceText: String = ""
    @State private var currency: String = "EUR"
    @State private var colorHex: String = appColorPalette[0]

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles") {
                    TextField("Nombre", text: $name)
                    Picker("Tipo", selection: $type) {
                        ForEach(AccountType.allCases.filter { $0 != .investmentManual }) { accountType in
                            Text(accountType.displayName).tag(accountType)
                        }
                    }
                    TextField("Saldo inicial", text: $initialBalanceText)
                        .keyboardType(.decimalPad)
                    TextField("Moneda", text: $currency)
                }
                .listRowBackground(Color.appCard)

                Section("Color") {
                    ColorSwatchGrid(selection: $colorHex)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.appCard)
            }
            .navigationTitle("Nueva cuenta")
            .themedListBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let balance = Decimal(string: initialBalanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let account = Account(
            name: name,
            type: type,
            currentBalance: balance,
            currency: currency.isEmpty ? "EUR" : currency,
            colorHex: colorHex
        )
        modelContext.insert(account)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddAccountView()
        .modelContainer(PreviewData.container)
}
