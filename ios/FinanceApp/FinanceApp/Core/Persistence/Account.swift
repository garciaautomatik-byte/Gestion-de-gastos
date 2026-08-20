import Foundation
import SwiftData

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case checking
    case savings
    case creditCard
    case investmentManual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checking: return "Corriente"
        case .savings: return "Ahorro"
        case .creditCard: return "Tarjeta"
        case .investmentManual: return "Inversión"
        }
    }
}

@Model
final class Account {
    var id: UUID
    var name: String
    var type: AccountType
    var ibanLast4: String?
    var currentBalance: Decimal
    var currency: String
    var isManual: Bool
    // Stored default (not just an init default) so SwiftData's lightweight migration can
    // backfill this on rows that existed before the field was added.
    var colorHex: String = "#34C759"
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MoneyTransaction.account)
    var transactions: [MoneyTransaction] = []

    @Relationship(deleteRule: .cascade, inverse: \Holding.account)
    var holdings: [Holding] = []

    // Nullify, not cascade: deleting the bank account you happened to pay with shouldn't wipe
    // out the investment operation itself, just detach it.
    @Relationship(deleteRule: .nullify, inverse: \InvestmentTransaction.fundingAccount)
    var investmentPayments: [InvestmentTransaction] = []

    @Relationship(deleteRule: .cascade, inverse: \RecurringTransaction.account)
    var recurringTransactions: [RecurringTransaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        ibanLast4: String? = nil,
        currentBalance: Decimal = 0,
        currency: String = "EUR",
        isManual: Bool = true,
        colorHex: String = "#34C759",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.ibanLast4 = ibanLast4
        self.currentBalance = currentBalance
        self.currency = currency
        self.isManual = isManual
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
