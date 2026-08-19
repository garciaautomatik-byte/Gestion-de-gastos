import SwiftUI
import SwiftData

struct AccountDetailView: View {
    let account: Account
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: AccountType = .checking
    @State private var currency: String = "EUR"
    @State private var balanceText: String = ""
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Detalles") {
                TextField("Nombre", text: $name)
                Picker("Tipo", selection: $type) {
                    ForEach(AccountType.allCases.filter { $0 != .investmentManual }) { accountType in
                        Text(accountType.displayName).tag(accountType)
                    }
                }
                TextField("Moneda", text: $currency)
            }

            Section {
                TextField("Saldo", text: $balanceText)
                    .keyboardType(.decimalPad)
            } footer: {
                Text("Cambia el saldo directamente aquí; no se crea ningún movimiento en el historial.")
            }

            Section {
                Button("Eliminar cuenta", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            name = account.name
            type = account.type
            currency = account.currency
            balanceText = NSDecimalNumber(decimal: account.currentBalance).stringValue
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

    private func save() {
        account.name = name
        account.type = type
        account.currency = currency.trimmingCharacters(in: .whitespaces).isEmpty ? "EUR" : currency
        if let balance = Decimal(string: balanceText.replacingOccurrences(of: ",", with: ".")) {
            account.currentBalance = balance
        }
        try? modelContext.save()
        dismiss()
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
