import Foundation
import SwiftData

@Model
final class RecurringTransaction {
    var id: UUID
    var transactionDescription: String
    var amount: Decimal
    var currency: String
    var kind: CategoryKind
    var dayOfMonth: Int
    var isActive: Bool = true
    // Month in which this rule last generated a MoneyTransaction, so the processor knows
    // where to resume and never generates the same month twice.
    var lastRunDate: Date?
    var createdAt: Date

    var account: Account?
    var category: Category?

    init(
        id: UUID = UUID(),
        transactionDescription: String,
        amount: Decimal,
        currency: String = "EUR",
        kind: CategoryKind,
        dayOfMonth: Int,
        isActive: Bool = true,
        lastRunDate: Date? = nil,
        account: Account? = nil,
        category: Category? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.transactionDescription = transactionDescription
        self.amount = amount
        self.currency = currency
        self.kind = kind
        self.dayOfMonth = dayOfMonth
        self.isActive = isActive
        self.lastRunDate = lastRunDate
        self.account = account
        self.category = category
        self.createdAt = createdAt
    }

    var signedAmount: Decimal {
        kind == .expense ? -abs(amount) : abs(amount)
    }
}
