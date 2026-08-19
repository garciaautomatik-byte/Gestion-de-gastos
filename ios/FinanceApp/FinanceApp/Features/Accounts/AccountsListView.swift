import SwiftUI
import SwiftData

struct AccountsListView: View {
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddAccount = false

    private var bankAccounts: [Account] {
        accounts.filter { $0.type != .investmentManual }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(bankAccounts) { account in
                    NavigationLink {
                        AccountDetailView(account: account)
                    } label: {
                        AccountRow(account: account)
                    }
                }
                .onDelete(perform: deleteAccounts)
            }
            .navigationTitle("Cuentas")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Label("Añadir", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if bankAccounts.isEmpty {
                    ContentUnavailableView(
                        "Sin cuentas",
                        systemImage: "creditcard",
                        description: Text("Añade tu primera cuenta con el botón +")
                    )
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
        }
    }

    private func deleteAccounts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bankAccounts[index])
        }
    }
}

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name)
                Text(account.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(account.currentBalance, format: .currency(code: account.currency))
                .foregroundStyle(account.currentBalance < 0 ? Color.red : Color.primary)
        }
    }
}

#Preview {
    AccountsListView()
        .modelContainer(PreviewData.container)
}
