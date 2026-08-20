import SwiftUI
import SwiftData

private let categoryIconOptions = [
    "cart.fill", "car.fill", "house.fill", "gamecontroller.fill", "cross.case.fill",
    "bag.fill", "fork.knife", "arrow.triangle.2.circlepath", "ellipsis.circle.fill",
    "banknote.fill", "briefcase.fill", "chart.line.uptrend.xyaxis", "plus.circle.fill",
    "airplane", "tram.fill", "fuelpump.fill", "pawprint.fill", "gift.fill",
    "heart.fill", "book.fill", "graduationcap.fill", "wrench.and.screwdriver.fill",
    "phone.fill", "wifi", "tshirt.fill", "cup.and.saucer.fill", "figure.run",
    "pills.fill", "creditcard.fill", "dollarsign.circle.fill"
]

struct AddEditCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var existingCategory: Category?

    @State private var name: String
    @State private var kind: CategoryKind
    @State private var icon: String
    @State private var colorHex: String

    private let iconColumns = Array(repeating: GridItem(.flexible()), count: 6)

    init(existingCategory: Category? = nil, defaultKind: CategoryKind = .expense) {
        self.existingCategory = existingCategory
        _name = State(initialValue: existingCategory?.name ?? "")
        _kind = State(initialValue: existingCategory?.kind ?? defaultKind)
        _icon = State(initialValue: existingCategory?.icon ?? categoryIconOptions[0])
        _colorHex = State(initialValue: existingCategory?.colorHex ?? appColorPalette[0])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(Color(hex: colorHex))
                                .frame(width: 56, height: 56)
                                .background(Color(hex: colorHex).opacity(0.15))
                                .clipShape(Circle())
                            Text(name.isEmpty ? "Vista previa" : name)
                                .font(.subheadline.bold())
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.appCard)

                Section("Detalles") {
                    TextField("Nombre", text: $name)
                    Picker("Tipo", selection: $kind) {
                        Text("Gasto").tag(CategoryKind.expense)
                        Text("Ingreso").tag(CategoryKind.income)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.appCard)

                Section("Icono") {
                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(categoryIconOptions, id: \.self) { option in
                            Button {
                                icon = option
                            } label: {
                                Image(systemName: option)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(icon == option ? Color(hex: colorHex).opacity(0.25) : Color.appCardSecondary)
                                    .foregroundStyle(icon == option ? Color(hex: colorHex) : Color.primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.appCard)

                Section("Color") {
                    ColorSwatchGrid(selection: $colorHex)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.appCard)
            }
            .navigationTitle(existingCategory == nil ? "Nueva categoría" : "Editar categoría")
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
        if let existingCategory {
            existingCategory.name = name
            existingCategory.kind = kind
            existingCategory.icon = icon
            existingCategory.colorHex = colorHex
        } else {
            let maxOrder = (try? modelContext.fetch(FetchDescriptor<Category>()))?.map(\.sortOrder).max() ?? 0
            let category = Category(
                name: name,
                kind: kind,
                icon: icon,
                colorHex: colorHex,
                isSystemDefault: false,
                sortOrder: maxOrder + 1
            )
            modelContext.insert(category)
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddEditCategoryView()
        .modelContainer(PreviewData.container)
}
