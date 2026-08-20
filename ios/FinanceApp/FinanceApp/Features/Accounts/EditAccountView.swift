import SwiftUI
import SwiftData

struct EditAccountView: View {
    let account: Account
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var type: AccountType
    @State private var currency: String
    @State private var colorHex: String

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _type = State(initialValue: account.type)
        _currency = State(initialValue: account.currency)
        _colorHex = State(initialValue: account.colorHex)
    }

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
                    TextField("Moneda", text: $currency)
                }
                .listRowBackground(Color.appCard)

                Section("Color") {
                    ColorSwatchGrid(selection: $colorHex)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.appCard)
            }
            .navigationTitle("Editar cuenta")
            .themedListBackground()
            .navigationBarTitleDisplayMode(.inline)
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
        account.name = name
        account.type = type
        account.currency = currency.trimmingCharacters(in: .whitespaces).isEmpty ? "EUR" : currency
        account.colorHex = colorHex
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let container = PreviewData.container
    let account = try! container.mainContext.fetch(FetchDescriptor<Account>()).first!
    return EditAccountView(account: account)
        .modelContainer(container)
}
