import Foundation
import SwiftData

private struct AccountDTO: Codable {
    var id: UUID
    var name: String
    var type: String
    var ibanLast4: String?
    var currentBalance: Decimal
    var currency: String
    var isManual: Bool
    var createdAt: Date
}

private struct CategoryDTO: Codable {
    var id: UUID
    var name: String
    var kind: String
    var icon: String
    var colorHex: String
    var isSystemDefault: Bool
    var parentCategoryID: UUID?
}

private struct MoneyTransactionDTO: Codable {
    var id: UUID
    var amount: Decimal
    var currency: String
    var date: Date
    var transactionDescription: String
    var merchantName: String?
    var isPending: Bool
    var externalId: String?
    var source: String
    var isTransfer: Bool
    var transferPairID: UUID?
    var createdAt: Date
    var accountID: UUID?
    var categoryID: UUID?
}

private struct HoldingDTO: Codable {
    var id: UUID
    var ticker: String
    var name: String
    var assetType: String
    var currency: String
    var currentPrice: Decimal?
    var priceUpdatedAt: Date?
    var exchange: String?
    var createdAt: Date
    var accountID: UUID?
}

private struct InvestmentTransactionDTO: Codable {
    var id: UUID
    var type: String
    var quantity: Decimal
    var pricePerUnit: Decimal
    var date: Date
    var fees: Decimal
    var holdingID: UUID?
    var fundingAccountID: UUID?
}

private struct RecurringTransactionDTO: Codable {
    var id: UUID
    var transactionDescription: String
    var amount: Decimal
    var currency: String
    var kind: String
    var dayOfMonth: Int
    var isActive: Bool
    var lastRunDate: Date?
    var createdAt: Date
    var accountID: UUID?
    var categoryID: UUID?
}

private struct AppBackup: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var accounts: [AccountDTO]
    var categories: [CategoryDTO]
    var transactions: [MoneyTransactionDTO]
    var holdings: [HoldingDTO]
    var investmentTransactions: [InvestmentTransactionDTO]
    var recurringTransactions: [RecurringTransactionDTO]
}

enum BackupError: LocalizedError {
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "El archivo no tiene el formato de una copia de seguridad de FinanceApp."
        }
    }
}

@MainActor
enum BackupService {
    private static let schemaVersion = 1

    static func export(context: ModelContext) throws -> Data {
        let backup = AppBackup(
            schemaVersion: schemaVersion,
            exportedAt: .now,
            accounts: try context.fetch(FetchDescriptor<Account>()).map { account in
                AccountDTO(
                    id: account.id,
                    name: account.name,
                    type: account.type.rawValue,
                    ibanLast4: account.ibanLast4,
                    currentBalance: account.currentBalance,
                    currency: account.currency,
                    isManual: account.isManual,
                    createdAt: account.createdAt
                )
            },
            categories: try context.fetch(FetchDescriptor<Category>()).map { category in
                CategoryDTO(
                    id: category.id,
                    name: category.name,
                    kind: category.kind.rawValue,
                    icon: category.icon,
                    colorHex: category.colorHex,
                    isSystemDefault: category.isSystemDefault,
                    parentCategoryID: category.parentCategory?.id
                )
            },
            transactions: try context.fetch(FetchDescriptor<MoneyTransaction>()).map { transaction in
                MoneyTransactionDTO(
                    id: transaction.id,
                    amount: transaction.amount,
                    currency: transaction.currency,
                    date: transaction.date,
                    transactionDescription: transaction.transactionDescription,
                    merchantName: transaction.merchantName,
                    isPending: transaction.isPending,
                    externalId: transaction.externalId,
                    source: transaction.source.rawValue,
                    isTransfer: transaction.isTransfer,
                    transferPairID: transaction.transferPairID,
                    createdAt: transaction.createdAt,
                    accountID: transaction.account?.id,
                    categoryID: transaction.category?.id
                )
            },
            holdings: try context.fetch(FetchDescriptor<Holding>()).map { holding in
                HoldingDTO(
                    id: holding.id,
                    ticker: holding.ticker,
                    name: holding.name,
                    assetType: holding.assetType.rawValue,
                    currency: holding.currency,
                    currentPrice: holding.currentPrice,
                    priceUpdatedAt: holding.priceUpdatedAt,
                    exchange: holding.exchange,
                    createdAt: holding.createdAt,
                    accountID: holding.account?.id
                )
            },
            investmentTransactions: try context.fetch(FetchDescriptor<InvestmentTransaction>()).map { transaction in
                InvestmentTransactionDTO(
                    id: transaction.id,
                    type: transaction.type.rawValue,
                    quantity: transaction.quantity,
                    pricePerUnit: transaction.pricePerUnit,
                    date: transaction.date,
                    fees: transaction.fees,
                    holdingID: transaction.holding?.id,
                    fundingAccountID: transaction.fundingAccount?.id
                )
            },
            recurringTransactions: try context.fetch(FetchDescriptor<RecurringTransaction>()).map { rule in
                RecurringTransactionDTO(
                    id: rule.id,
                    transactionDescription: rule.transactionDescription,
                    amount: rule.amount,
                    currency: rule.currency,
                    kind: rule.kind.rawValue,
                    dayOfMonth: rule.dayOfMonth,
                    isActive: rule.isActive,
                    lastRunDate: rule.lastRunDate,
                    createdAt: rule.createdAt,
                    accountID: rule.account?.id,
                    categoryID: rule.category?.id
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// Wipes every entity in the store and recreates it from the file, reusing the original
    /// UUIDs to rebuild relationships. A full replace (not a merge) is the only restore that
    /// can't produce duplicate accounts/categories if this is imported into a store that
    /// already auto-seeded its own default categories on first launch.
    static func importBackup(data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: AppBackup
        do {
            backup = try decoder.decode(AppBackup.self, from: data)
        } catch {
            throw BackupError.invalidFile
        }

        // Leaves first, so this doesn't depend on the relationships' delete rules to cascade
        // in the right order.
        try deleteAll(InvestmentTransaction.self, context: context)
        try deleteAll(RecurringTransaction.self, context: context)
        try deleteAll(MoneyTransaction.self, context: context)
        try deleteAll(Holding.self, context: context)
        try deleteAll(Account.self, context: context)
        try deleteAll(Category.self, context: context)
        try context.save()

        var accountsByID: [UUID: Account] = [:]
        for dto in backup.accounts {
            let account = Account(
                id: dto.id,
                name: dto.name,
                type: AccountType(rawValue: dto.type) ?? .checking,
                ibanLast4: dto.ibanLast4,
                currentBalance: dto.currentBalance,
                currency: dto.currency,
                isManual: dto.isManual,
                createdAt: dto.createdAt
            )
            context.insert(account)
            accountsByID[dto.id] = account
        }

        var categoriesByID: [UUID: Category] = [:]
        for dto in backup.categories {
            let category = Category(
                id: dto.id,
                name: dto.name,
                kind: CategoryKind(rawValue: dto.kind) ?? .expense,
                icon: dto.icon,
                colorHex: dto.colorHex,
                isSystemDefault: dto.isSystemDefault
            )
            context.insert(category)
            categoriesByID[dto.id] = category
        }
        for dto in backup.categories {
            guard let parentID = dto.parentCategoryID else { continue }
            categoriesByID[dto.id]?.parentCategory = categoriesByID[parentID]
        }

        for dto in backup.transactions {
            let transaction = MoneyTransaction(
                id: dto.id,
                amount: dto.amount,
                currency: dto.currency,
                date: dto.date,
                transactionDescription: dto.transactionDescription,
                merchantName: dto.merchantName,
                isPending: dto.isPending,
                externalId: dto.externalId,
                source: TransactionSource(rawValue: dto.source) ?? .manual,
                isTransfer: dto.isTransfer,
                transferPairID: dto.transferPairID,
                account: dto.accountID.flatMap { accountsByID[$0] },
                category: dto.categoryID.flatMap { categoriesByID[$0] },
                createdAt: dto.createdAt
            )
            context.insert(transaction)
        }

        var holdingsByID: [UUID: Holding] = [:]
        for dto in backup.holdings {
            let holding = Holding(
                id: dto.id,
                ticker: dto.ticker,
                name: dto.name,
                assetType: AssetType(rawValue: dto.assetType) ?? .other,
                currency: dto.currency,
                currentPrice: dto.currentPrice,
                priceUpdatedAt: dto.priceUpdatedAt,
                exchange: dto.exchange,
                account: dto.accountID.flatMap { accountsByID[$0] },
                createdAt: dto.createdAt
            )
            context.insert(holding)
            holdingsByID[dto.id] = holding
        }

        for dto in backup.investmentTransactions {
            let transaction = InvestmentTransaction(
                id: dto.id,
                type: InvestmentTransactionType(rawValue: dto.type) ?? .buy,
                quantity: dto.quantity,
                pricePerUnit: dto.pricePerUnit,
                date: dto.date,
                fees: dto.fees,
                holding: dto.holdingID.flatMap { holdingsByID[$0] },
                fundingAccount: dto.fundingAccountID.flatMap { accountsByID[$0] }
            )
            context.insert(transaction)
        }

        for dto in backup.recurringTransactions {
            let rule = RecurringTransaction(
                id: dto.id,
                transactionDescription: dto.transactionDescription,
                amount: dto.amount,
                currency: dto.currency,
                kind: CategoryKind(rawValue: dto.kind) ?? .expense,
                dayOfMonth: dto.dayOfMonth,
                isActive: dto.isActive,
                lastRunDate: dto.lastRunDate,
                account: dto.accountID.flatMap { accountsByID[$0] },
                category: dto.categoryID.flatMap { categoriesByID[$0] },
                createdAt: dto.createdAt
            )
            context.insert(rule)
        }

        try context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<T>()) {
            context.delete(item)
        }
    }
}
