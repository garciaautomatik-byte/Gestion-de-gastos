import SwiftUI
import SwiftData

struct AddTransferView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var sourceAccount: Account?
    @State private var destinationAccount: Account?
    @State private var amountText: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""

    private var eligibleAccounts: [Account] {
        accounts.filter { $0.type != .investmentManual }
    }

    var body: some View {
        NavigationStack {
            Form {
                if eligibleAccounts.count < 2 {
                    Section {
                        Text("Necesitas al menos dos cuentas para hacer una transferencia.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Desde") {
                        Picker("Cuenta origen", selection: $sourceAccount) {
                            Text("Selecciona una cuenta").tag(Account?.none)
                            ForEach(eligibleAccounts) { account in
                                Text(account.name).tag(Account?.some(account))
                            }
                        }
                    }

                    Section("Hacia") {
                        Picker("Cuenta destino", selection: $destinationAccount) {
                            Text("Selecciona una cuenta").tag(Account?.none)
                            ForEach(eligibleAccounts.filter { $0.id != sourceAccount?.id }) { account in
                                Text(account.name).tag(Account?.some(account))
                            }
                        }
                    }

                    Section("Detalles") {
                        TextField("Importe", text: $amountText)
                            .keyboardType(.decimalPad)
                        DatePicker("Fecha", selection: $date, displayedComponents: .date)
                        TextField("Nota (opcional)", text: $note)
                    }
                }
            }
            .navigationTitle("Transferencia")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!isValid)
                }
            }
            .onChange(of: sourceAccount) {
                if destinationAccount?.id == sourceAccount?.id {
                    destinationAccount = nil
                }
            }
        }
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        guard let source = sourceAccount, let destination = destinationAccount, source.id != destination.id else { return false }
        guard let amount = parsedAmount, amount > 0 else { return false }
        return true
    }

    private func save() {
        guard let source = sourceAccount, let destination = destinationAccount,
              let amount = parsedAmount, amount > 0 else { return }

        let pairID = UUID()
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        let noteSuffix = trimmedNote.isEmpty ? "" : " – \(trimmedNote)"

        let outgoing = MoneyTransaction(
            amount: -amount,
            currency: source.currency,
            date: date,
            transactionDescription: "Transferencia a \(destination.name)\(noteSuffix)",
            isTransfer: true,
            transferPairID: pairID,
            account: source
        )
        let incoming = MoneyTransaction(
            amount: amount,
            currency: destination.currency,
            date: date,
            transactionDescription: "Transferencia desde \(source.name)\(noteSuffix)",
            isTransfer: true,
            transferPairID: pairID,
            account: destination
        )

        modelContext.insert(outgoing)
        modelContext.insert(incoming)

        source.currentBalance -= amount
        destination.currentBalance += amount

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddTransferView()
        .modelContainer(PreviewData.container)
}
