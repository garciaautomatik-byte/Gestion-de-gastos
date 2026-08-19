import SwiftUI

struct DashboardCustomizeView: View {
    @Binding var order: [DashboardWidget]
    @Binding var hidden: Set<DashboardWidget>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(order) { widget in
                        HStack {
                            Image(systemName: widget.icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(widget.title)
                                .foregroundStyle(hidden.contains(widget) ? Color.secondary : Color.primary)
                            Spacer()
                            Button {
                                toggle(widget)
                            } label: {
                                Image(systemName: hidden.contains(widget) ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(hidden.contains(widget) ? Color.secondary : Color.accentColor)
                        }
                    }
                    .onMove(perform: move)
                } footer: {
                    Text("Arrastra para reordenar. Toca el ojo para mostrar u ocultar una sección en Resumen.")
                }
            }
            .navigationTitle("Personalizar Resumen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ widget: DashboardWidget) {
        if hidden.contains(widget) {
            hidden.remove(widget)
        } else {
            hidden.insert(widget)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview {
    DashboardCustomizeView(order: .constant(DashboardWidget.allCases), hidden: .constant([.investments]))
}
