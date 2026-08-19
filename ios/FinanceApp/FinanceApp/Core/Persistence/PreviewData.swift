import Foundation
import SwiftData

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let schema = Schema([Account.self, MoneyTransaction.self, Category.self, Holding.self, InvestmentTransaction.self, RecurringTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])

        let context = container.mainContext
        DefaultCategories.seedIfNeeded(context: context)

        let checking = Account(name: "Cuenta corriente", type: .checking, currentBalance: 1500)
        context.insert(checking)

        let groceries = try? context.fetch(
            FetchDescriptor<Category>(predicate: #Predicate { $0.name == "Alimentación" })
        ).first

        context.insert(
            MoneyTransaction(amount: -42.50, transactionDescription: "Mercadona", account: checking, category: groceries)
        )

        try? context.save()
        return container
    }()
}
