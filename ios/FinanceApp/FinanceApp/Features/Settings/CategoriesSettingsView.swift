import SwiftUI
import SwiftData

struct CategoriesSettingsView: View {
    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)]) private var categories: [Category]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedKind: CategoryKind = .expense
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?

    private var filteredCategories: [Category] {
        categories.filter { $0.kind == selectedKind }
    }

    var body: some View {
        List {
            Section {
                Picker("Tipo", selection: $selectedKind) {
                    Text("Gastos").tag(CategoryKind.expense)
                    Text("Ingresos").tag(CategoryKind.income)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } footer: {
                Text("Mantén pulsada una categoría para arrastrarla y reordenarla. Toca el ojo para ocultar las que no uses.")
            }
            .listRowBackground(Color.appCard)

            Section {
                ForEach(filteredCategories) { category in
                    CategoryRow(category: category) {
                        editingCategory = category
                    } onToggleHidden: {
                        toggleHidden(category)
                    }
                }
                .onMove(perform: move)
            }
            .listRowBackground(Color.appCard)
        }
        .navigationTitle("Categorías")
        .themedListBackground()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCategory = true
                } label: {
                    Label("Añadir", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddEditCategoryView(defaultKind: selectedKind)
        }
        .sheet(item: $editingCategory) { category in
            AddEditCategoryView(existingCategory: category)
        }
    }

    private func toggleHidden(_ category: Category) {
        category.isHidden.toggle()
        try? modelContext.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = filteredCategories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
        try? modelContext.save()
    }
}

private struct CategoryRow: View {
    let category: Category
    let onEdit: () -> Void
    let onToggleHidden: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: category.colorHex).opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: category.icon)
                        .foregroundStyle(Color(hex: category.colorHex))
                        .font(.subheadline)
                }
            Text(category.name)
                .foregroundStyle(category.isHidden ? Color.secondary : Color.primary)
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Button(action: onToggleHidden) {
                Image(systemName: category.isHidden ? "eye.slash" : "eye")
            }
            .buttonStyle(.plain)
            .foregroundStyle(category.isHidden ? Color.secondary : Color.accentColor)
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesSettingsView()
    }
    .modelContainer(PreviewData.container)
}
