import Foundation
import SwiftData

enum AssetType: String, Codable, CaseIterable, Identifiable {
    case stock
    case etf
    case fund
    case crypto
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stock: return "Acción"
        case .etf: return "ETF"
        case .fund: return "Fondo"
        case .crypto: return "Cripto"
        case .other: return "Otro"
        }
    }

    /// Yahoo Finance's `quoteType` string for this asset type, used to sort symbol search
    /// results so the closest matches show first. Not a hard filter: Yahoo's own type labels
    /// are inconsistent enough that excluding non-matches outright would hide valid results.
    var yahooQuoteType: String? {
        switch self {
        case .stock: return "EQUITY"
        case .etf: return "ETF"
        case .fund: return "MUTUALFUND"
        case .crypto: return "CRYPTOCURRENCY"
        case .other: return nil
        }
    }
}

@Model
final class Holding {
    var id: UUID
    var ticker: String
    var name: String
    var assetType: AssetType
    var currency: String
    var createdAt: Date

    // Cached market price from the price API (Core/Networking/PriceService), refreshed on
    // demand rather than automatically, to be a good citizen of Yahoo's unofficial endpoints.
    var currentPrice: Decimal?
    var priceUpdatedAt: Date?
    // Display-only (e.g. "XETRA"). Yahoo's ticker (e.g. VWCE.DE) already encodes which listing
    // this is, unlike the previous price provider where it had to be passed separately.
    var exchange: String?

    var account: Account?

    @Relationship(deleteRule: .cascade, inverse: \InvestmentTransaction.holding)
    var investmentTransactions: [InvestmentTransaction] = []

    init(
        id: UUID = UUID(),
        ticker: String,
        name: String,
        assetType: AssetType,
        currency: String = "EUR",
        currentPrice: Decimal? = nil,
        priceUpdatedAt: Date? = nil,
        exchange: String? = nil,
        account: Account? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ticker = ticker
        self.name = name
        self.assetType = assetType
        self.currency = currency
        self.currentPrice = currentPrice
        self.priceUpdatedAt = priceUpdatedAt
        self.exchange = exchange
        self.account = account
        self.createdAt = createdAt
    }

    /// Net units held: buys add, sells subtract, dividends don't affect quantity.
    var quantity: Decimal {
        investmentTransactions.reduce(Decimal(0)) { total, tx in
            switch tx.type {
            case .buy: return total + tx.quantity
            case .sell: return total - tx.quantity
            case .dividend: return total
            }
        }
    }

    /// Net cash invested (buys + fees add, sells - fees reduce). Dividends aren't cost basis.
    var totalCost: Decimal {
        investmentTransactions.reduce(Decimal(0)) { total, tx in
            switch tx.type {
            case .buy: return total + (tx.quantity * tx.pricePerUnit) + tx.fees
            case .sell: return total - (tx.quantity * tx.pricePerUnit) + tx.fees
            case .dividend: return total
            }
        }
    }

    var averageCost: Decimal {
        guard quantity > 0 else { return 0 }
        return totalCost / quantity
    }

    var marketValue: Decimal? {
        guard let currentPrice else { return nil }
        return currentPrice * quantity
    }

    var gainLoss: Decimal? {
        guard let marketValue else { return nil }
        return marketValue - totalCost
    }

    var gainLossPercent: Double? {
        guard let gainLoss, totalCost > 0 else { return nil }
        return NSDecimalNumber(decimal: gainLoss / totalCost).doubleValue
    }
}
