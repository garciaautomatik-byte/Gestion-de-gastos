import SwiftUI

struct DashboardCustomizeView: View {
    @Binding var order: [DashboardWidget]
    @Binding var hidden: Set<DashboardWidget>
    @Binding var styles: [DashboardWidget: DashboardWidgetStyle]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(order) { widget in
                        VStack(alignment: .leading, spacing: 10) {
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

                            if !hidden.contains(widget) {
                                Picker("Estilo", selection: styleBinding(for: widget)) {
                                    ForEach(DashboardWidgetStyle.allCases) { style in
                                        Text(style.title).tag(style)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: move)
                } footer: {
                    Text("Arrastra para reordenar. El ojo muestra u oculta una sección en Resumen; el estilo cambia cómo se presenta (Detallado, Compacto o Tarjeta).")
                }
                .listRowBackground(Color.appCard)
            }
            .navigationTitle("Personalizar Resumen")
            .themedListBackground()
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

    private func styleBinding(for widget: DashboardWidget) -> Binding<DashboardWidgetStyle> {
        Binding(
            get: { styles[widget] ?? .detailed },
            set: { styles[widget] = $0 }
        )
    }
}

#Preview {
    DashboardCustomizeView(
        order: .constant(DashboardWidget.allCases),
        hidden: .constant([.investments]),
        styles: .constant([:])
    )
}
