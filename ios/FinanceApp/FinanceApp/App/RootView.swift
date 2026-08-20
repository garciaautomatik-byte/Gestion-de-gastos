import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Resumen", systemImage: "chart.pie.fill") }
            AccountsListView()
                .tabItem { Label("Cuentas", systemImage: "creditcard.fill") }
            StatisticsView(embedded: true)
                .tabItem { Label("Movimientos", systemImage: "list.bullet") }
            InvestmentsListView()
                .tabItem { Label("Inversiones", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .task {
            DefaultCategories.seedIfNeeded(context: modelContext)
            RecurringTransactionProcessor.processDueTransactions(context: modelContext)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}
