import Foundation
import SwiftData

enum InvestmentTransactionType: String, Codable, CaseIterable, Identifiable {
    case buy
    case sell
    case dividend

    var id: String { rawValue }
}

@Model
final class InvestmentTransaction {
    var id: UUID
    var type: InvestmentTransactionType
    var quantity: Decimal
    var pricePerUnit: Decimal
    var date: Date
    var fees: Decimal

    var holding: Holding?
    // The bank account the cash for this operation moved in/out of. Optional only so existing
    // rows from before this field existed keep loading; new operations always ask for one.
    var fundingAccount: Account?

    init(
        id: UUID = UUID(),
        type: InvestmentTransactionType,
        quantity: Decimal,
        pricePerUnit: Decimal,
        date: Date = .now,
        fees: Decimal = 0,
        holding: Holding? = nil,
        fundingAccount: Account? = nil
    ) {
        self.id = id
        self.type = type
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.date = date
        self.fees = fees
        self.holding = holding
        self.fundingAccount = fundingAccount
    }

    /// Signed cash movement in the funding account for this operation: negative for a buy
    /// (cash leaves), positive for a sell or dividend (cash arrives). Used both when the
    /// operation is created and reverted (deleted), so the account balance stays consistent.
    var cashImpact: Decimal {
        let gross = quantity * pricePerUnit
        switch type {
        case .buy: return -(gross + fees)
        case .sell: return gross - fees
        case .dividend: return gross - fees
        }
    }
}
