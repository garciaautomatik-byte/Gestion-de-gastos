import SwiftUI
import SwiftData

struct AdjustBalanceView: View {
    let account: Account
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var balanceText: String

    init(account: Account) {
        self.account = account
        _balanceText = State(initialValue: NSDecimalNumber(decimal: account.currentBalance).stringValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Saldo", text: $balanceText)
                        .keyboardType(.decimalPad)
                } footer: {
                    Text("Ajusta el saldo directamente; no se crea ningún movimiento en el historial.")
                }
                .listRowBackground(Color.appCard)
            }
            .navigationTitle("Ajustar saldo")
            .themedListBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                }
            }
        }
    }

    private func save() {
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
    return AdjustBalanceView(account: account)
        .modelContainer(container)
}
