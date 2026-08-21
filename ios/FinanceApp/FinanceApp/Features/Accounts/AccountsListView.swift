import SwiftUI
import SwiftData

private struct AccountCardPage: Identifiable, Equatable {
    let id: String
    let account: Account?
}

struct AccountsListView: View {
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \MoneyTransaction.date, order: .reverse) private var allTransactions: [MoneyTransaction]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddAccount = false
    @State private var showingAddIncome = false
    @State private var showingStatistics = false
    @State private var showingAllMovements = false
    @State private var transferAccount: Account?
    @State private var editAccount: Account?
    @State private var detailAccount: Account?
    @State private var selectedPageID: String?
    // Always starts hidden: masked again every time this view is created (app launch, or
    // returning to the Cuentas tab after the app was backgrounded and reloaded).
    @State private var isBalanceRevealed = false

    private var bankAccounts: [Account] {
        accounts.filter { $0.type != .investmentManual }
    }

    private var pages: [AccountCardPage] {
        [AccountCardPage(id: "total", account: nil)] + bankAccounts.map { AccountCardPage(id: $0.id.uuidString, account: $0) }
    }

    private var currentPage: AccountCardPage? {
        pages.first { $0.id == selectedPageID } ?? pages.first
    }

    private var totalBalance: Decimal {
        bankAccounts.reduce(Decimal(0)) { $0 + $1.currentBalance }
    }

    private var recentMovements: [MoneyTransaction] {
        if let account = currentPage?.account {
            return Array(account.transactions.sorted { $0.date > $1.date }.prefix(6))
        }
        return Array(allTransactions.prefix(6))
    }

    var body: some View {
        NavigationStack {
            Group {
                if bankAccounts.isEmpty {
                    ContentUnavailableView(
                        "Sin cuentas",
                        systemImage: "creditcard",
                        description: Text("Añade tu primera cuenta con el botón +")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            carousel
                            pageDots
                            actionsRow
                            movementsSection
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Cuentas")
            .themedListBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { isBalanceRevealed.toggle() }
                    } label: {
                        Image(systemName: isBalanceRevealed ? "eye.slash" : "eye")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(Color.appCardSecondary, in: Circle())
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(Color.appCardSecondary, in: Circle())
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
            .sheet(isPresented: $showingAddIncome) {
                AddTransactionView(defaultKind: .income)
            }
            .sheet(isPresented: $showingStatistics) {
                StatisticsView()
            }
            .sheet(isPresented: $showingAllMovements) {
                AllMovementsSheet()
            }
            .sheet(item: $transferAccount) { account in
                AddTransferView(preselectedSourceAccount: account)
            }
            .sheet(item: $editAccount) { account in
                EditAccountView(account: account)
            }
            .navigationDestination(item: $detailAccount) { account in
                AccountDetailView(account: account)
            }
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(pages) { page in
                    AccountCardView(
                        page: page,
                        totalBalance: totalBalance,
                        accountCount: bankAccounts.count,
                        baseCurrency: bankAccounts.first?.currency ?? "EUR",
                        isRevealed: isBalanceRevealed
                    )
                    .containerRelativeFrame(.horizontal, count: 10, span: 9, spacing: 16)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedPageID)
        .frame(height: 190)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(pages) { page in
                Capsule()
                    .fill(page.id == currentPage?.id ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: page.id == currentPage?.id ? 16 : 6, height: 6)
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeOut(duration: 0.2), value: selectedPageID)
    }

    @ViewBuilder
    private var actionsRow: some View {
        HStack(spacing: 10) {
            if let account = currentPage?.account {
                AccountActionButton(title: "Transferir", icon: "arrow.left.arrow.right", subtitle: "Entre cuentas") {
                    transferAccount = account
                }
                AccountActionButton(title: "Editar", icon: "pencil", subtitle: "Nombre y color") {
                    editAccount = account
                }
                AccountActionButton(title: "Ver todo", icon: "chevron.right", subtitle: "Detalle y ajustes") {
                    detailAccount = account
                }
            } else {
                AccountActionButton(title: "Nueva cuenta", icon: "plus", subtitle: "Añade una cuenta") {
                    showingAddAccount = true
                }
                AccountActionButton(title: "Añadir dinero", icon: "arrow.down", subtitle: "Ingresa fondos") {
                    showingAddIncome = true
                }
                AccountActionButton(title: "Estadísticas", icon: "chart.bar.fill", subtitle: "Ver tus datos") {
                    showingStatistics = true
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var movementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(currentPage?.account?.name ?? "Todos los movimientos")
                    .font(.headline)
                Spacer()
                Button("Ver todo") {
                    if let account = currentPage?.account {
                        detailAccount = account
                    } else {
                        showingAllMovements = true
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 20)

            if recentMovements.isEmpty {
                Text("Sin movimientos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentMovements) { transaction in
                        TransactionRow(transaction: transaction)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        if transaction.id != recentMovements.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct AccountCardView: View {
    let page: AccountCardPage
    let totalBalance: Decimal
    let accountCount: Int
    let baseCurrency: String
    let isRevealed: Bool

    private var cardColor: Color {
        Color(hex: page.account?.colorHex ?? "#30D158")
    }

    private var title: String { page.account?.name ?? "Saldo total" }
    private var currency: String { page.account?.currency ?? baseCurrency }
    private var balance: Decimal { page.account?.currentBalance ?? totalBalance }
    private var balanceText: String {
        isRevealed ? balance.formatted(.currency(code: currency)) : "••••••"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Group {
                    if let account = page.account {
                        BankLogoView(name: account.name, fallbackColor: .white.opacity(0.22), diameter: 34)
                    } else {
                        Circle()
                            .fill(.white.opacity(0.22))
                            .overlay {
                                Image(systemName: "creditcard.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 34, height: 34)
                    }
                }

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)

                Spacer()

                MiniCardGraphic(accent: cardColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(balanceText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                if page.account == nil {
                    Text("En \(accountCount) \(accountCount == 1 ? "cuenta" : "cuentas")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text(currency)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: Capsule())
                Spacer()
            }
        }
        .padding(20)
        .frame(height: 190)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [cardColor, cardColor.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.1))
        }
        .shadow(color: cardColor.opacity(0.35), radius: 16, x: 0, y: 10)
    }
}

/// A generic pair of stacked, rotated card shapes with a chip accent — evokes "payment cards"
/// without depicting any real bank's card design or logo.
private struct MiniCardGraphic: View {
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.55))
                .frame(width: 52, height: 34)
                .rotationEffect(.degrees(-9))
                .offset(x: -9, y: 6)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.25))
                        .rotationEffect(.degrees(-9))
                        .offset(x: -9, y: 6)
                }

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white)
                .frame(width: 52, height: 34)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(accent)
                        .frame(width: 12, height: 8)
                        .padding(6)
                }
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 2) {
                        Circle().fill(accent.opacity(0.7)).frame(width: 6, height: 6)
                        Circle().fill(accent.opacity(0.35)).frame(width: 6, height: 6)
                    }
                    .padding(6)
                }
        }
    }
}

private struct AllMovementsSheet: View {
    @Query(sort: \MoneyTransaction.date, order: .reverse) private var transactions: [MoneyTransaction]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editingTransaction: MoneyTransaction?

    var body: some View {
        NavigationStack {
            List {
                ForEach(transactions) { transaction in
                    TransactionRow(transaction: transaction)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !transaction.isTransfer {
                                editingTransaction = transaction
                            }
                        }
                }
                .onDelete(perform: deleteTransactions)
                .listRowBackground(Color.appCard)
            }
            .navigationTitle("Todos los movimientos")
            .themedListBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionView(existingTransaction: transaction)
            }
            .overlay {
                if transactions.isEmpty {
                    ContentUnavailableView("Sin movimientos", systemImage: "list.bullet")
                }
            }
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let transaction = transactions[index]
            delete(transaction)
            if transaction.isTransfer, let pairID = transaction.transferPairID {
                let pairedLegs = transactions.filter { $0.transferPairID == pairID && $0.id != transaction.id }
                for leg in pairedLegs { delete(leg) }
            }
        }
    }

    private func delete(_ transaction: MoneyTransaction) {
        if let account = transaction.account {
            account.currentBalance -= transaction.amount
        }
        modelContext.delete(transaction)
    }
}

#Preview {
    AccountsListView()
        .modelContainer(PreviewData.container)
}
