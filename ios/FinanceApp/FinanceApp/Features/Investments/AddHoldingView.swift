import SwiftUI
import SwiftData

struct AddHoldingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var ticker: String = ""
    @State private var name: String = ""
    @State private var assetType: AssetType = .stock
    @State private var currency: String = "EUR"
    @State private var exchange: String?
    @State private var showingSymbolSearch = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo de activo", selection: $assetType) {
                        ForEach(AssetType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    HStack {
                        TextField("Ticker", text: $ticker)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button {
                            showingSymbolSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                    }
                    if let exchange {
                        LabeledContent("Bolsa", value: exchange)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Nombre", text: $name)
                    TextField("Moneda", text: $currency)
                } footer: {
                    Text("Usa la lupa para buscar el símbolo exacto (los resultados se priorizan según el tipo de activo elegido arriba), o escríbelo a mano si ya lo conoces. La moneda se actualiza sola la primera vez que se consulte el precio.")
                }
                .listRowBackground(Color.appCard)
            }
            .navigationTitle("Nueva posición")
            .themedListBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(ticker.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingSymbolSearch) {
                SymbolSearchView(preferredAssetType: assetType) { result in
                    ticker = result.symbol
                    exchange = result.exchange
                    if name.trimmingCharacters(in: .whitespaces).isEmpty {
                        name = result.instrumentName ?? result.symbol
                    }
                }
            }
        }
    }

    private func save() {
        let holding = Holding(
            ticker: ticker.uppercased(),
            name: name.isEmpty ? ticker.uppercased() : name,
            assetType: assetType,
            currency: currency.isEmpty ? "EUR" : currency,
            exchange: exchange
        )
        modelContext.insert(holding)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddHoldingView()
        .modelContainer(PreviewData.container)
}
