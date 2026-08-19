import Foundation
import SwiftData

enum TransactionSource: String, Codable {
    case manual
    case synced
}

// Named MoneyTransaction, not Transaction: SwiftData reproducibly crashes (EXC_BREAKPOINT
// inside SwiftData on the first insert()) when a @Model class is named "Transaction",
// evidently colliding with another "Transaction" type in the runtime (SwiftUI/StoreKit
// both declare one). Confirmed by bisecting the schema — every combination that included
// a model named exactly "Transaction" crashed; renaming it fixed it.
@Model
final class MoneyTransaction {
    var id: UUID
    var amount: Decimal
    var currency: String
    var date: Date
    // Named to avoid colliding with NSObject's `description` on SwiftData model classes.
    var transactionDescription: String
    var merchantName: String?
    var isPending: Bool
    var externalId: String?
    var source: TransactionSource
    // Given a stored default (not just an init default) so SwiftData's lightweight migration
    // can backfill this value on rows that existed before this property was added.
    var isTransfer: Bool = false
    // Shared by the two legs of a transfer (outgoing + incoming), so they can be found and
    // deleted/reverted together.
    var transferPairID: UUID?
    var createdAt: Date

    var account: Account?
    var category: Category?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        currency: String = "EUR",
        date: Date = .now,
        transactionDescription: String,
        merchantName: String? = nil,
        isPending: Bool = false,
        externalId: String? = nil,
        source: TransactionSource = .manual,
        isTransfer: Bool = false,
        transferPairID: UUID? = nil,
        account: Account? = nil,
        category: Category? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.date = date
        self.transactionDescription = transactionDescription
        self.merchantName = merchantName
        self.isPending = isPending
        self.externalId = externalId
        self.source = source
        self.isTransfer = isTransfer
        self.transferPairID = transferPairID
        self.account = account
        self.category = category
        self.createdAt = createdAt
    }
}
