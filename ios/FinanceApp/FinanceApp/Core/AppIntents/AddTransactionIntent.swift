import AppIntents
import SwiftData
import Foundation

enum AddTransactionIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case accountNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .accountNotFound: return "No se encontró la cuenta seleccionada."
        }
    }
}

struct AddTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "Añadir movimiento"
    static let description = IntentDescription("Registra un gasto o ingreso en una cuenta, sin abrir la app.")

    @Parameter(title: "Cuenta")
    var account: AccountEntity

    @Parameter(title: "Tipo")
    var kind: CategoryKind

    @Parameter(title: "Importe")
    var amount: Double

    @Parameter(title: "Descripción")
    var note: String

    @Parameter(title: "Categoría")
    var category: CategoryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Añadir \(\.$kind) de \(\.$amount) en \(\.$account)") {
            \.$note
            \.$category
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppModelContainer.shared.mainContext

        guard let matchedAccount = try context.fetch(FetchDescriptor<Account>()).first(where: { $0.id == account.id }) else {
            throw AddTransactionIntentError.accountNotFound
        }

        var matchedCategory: Category?
        if category.id != CategoryEntity.noCategoryID {
            matchedCategory = try context.fetch(FetchDescriptor<Category>()).first(where: { $0.id == category.id })
        }

        let signedAmount = kind == .expense ? -abs(Decimal(amount)) : abs(Decimal(amount))

        let transaction = MoneyTransaction(
            amount: signedAmount,
            currency: matchedAccount.currency,
            transactionDescription: note,
            source: .manual,
            account: matchedAccount,
            category: matchedCategory
        )
        context.insert(transaction)
        matchedAccount.currentBalance += signedAmount
        try context.save()

        let formattedAmount = signedAmount.formatted(.currency(code: matchedAccount.currency))
        return .result(dialog: "Movimiento añadido: \(formattedAmount) en \(matchedAccount.name).")
    }
}
