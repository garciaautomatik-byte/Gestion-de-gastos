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
    @State private var colorManuallySet = false

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _type = State(initialValue: account.type)
        _currency = State(initialValue: account.currency)
        _colorHex = State(initialValue: account.colorHex)
    }

    private var manualColorBinding: Binding<String> {
        Binding(get: { colorHex }, set: { colorHex = $0; colorManuallySet = true })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles") {
                    TextField("Nombre", text: $name)
                        .onChange(of: name) { _, newValue in
                            guard !colorManuallySet, let brand = BankBrandCatalog.match(for: newValue) else { return }
                            colorHex = brand.colorHex
                        }
                    Picker("Tipo", selection: $type) {
                        ForEach(AccountType.allCases.filter { $0 != .investmentManual }) { accountType in
                            Text(accountType.displayName).tag(accountType)
                        }
                    }
                    TextField("Moneda", text: $currency)
                }
                .listRowBackground(Color.appCard)

                Section("Color") {
                    ColorSwatchGrid(selection: manualColorBinding)
                        .padding(.vertical, 4)
                    if let brand = BankBrandCatalog.match(for: name), colorHex == brand.colorHex {
                        Label("Color de \(brand.name) detectado automáticamente", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
