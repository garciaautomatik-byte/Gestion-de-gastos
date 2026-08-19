import XCTest
import SwiftData
@testable import FinanceApp

// A single test method, sharing one ModelContainer: as of Xcode 26.5 / Swift 6.3, creating
// more than one in-memory ModelContainer from an identical Schema within the same test run
// reproducibly crashes inside SwiftData (EXC_BREAKPOINT) on the second container's first
// insert. Verified by bisection — this looks like a SwiftData/toolchain bug, not a modeling
// issue, so we work around it by keeping one container per test run instead of per test case.
@MainActor
final class HoldingTests: XCTestCase {
    func testHoldingCalculations() throws {
        let schema = Schema([Account.self, MoneyTransaction.self, Category.self, Holding.self, InvestmentTransaction.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext

        let quantityHolding = Holding(ticker: "AAPL", name: "Apple Inc.", assetType: .stock)
        context.insert(quantityHolding)
        context.insert(InvestmentTransaction(type: .buy, quantity: 10, pricePerUnit: 150, holding: quantityHolding))
        context.insert(InvestmentTransaction(type: .sell, quantity: 4, pricePerUnit: 160, holding: quantityHolding))

        XCTAssertEqual(quantityHolding.quantity, 6)

        let costHolding = Holding(ticker: "VWCE", name: "Vanguard FTSE All-World", assetType: .etf)
        context.insert(costHolding)
        context.insert(InvestmentTransaction(type: .buy, quantity: 10, pricePerUnit: 100, fees: 5, holding: costHolding))
        context.insert(InvestmentTransaction(type: .dividend, quantity: 0, pricePerUnit: 2, holding: costHolding))

        XCTAssertEqual(costHolding.totalCost, 1005)
        XCTAssertEqual(costHolding.averageCost, 100.5)

        // cashImpact drives how much a buy/sell/dividend debits or credits the funding account.
        let buy = InvestmentTransaction(type: .buy, quantity: 10, pricePerUnit: 100, fees: 5)
        XCTAssertEqual(buy.cashImpact, -1005) // pays 1000 + 5 fees

        let sell = InvestmentTransaction(type: .sell, quantity: 10, pricePerUnit: 100, fees: 5)
        XCTAssertEqual(sell.cashImpact, 995) // receives 1000 - 5 fees

        let dividend = InvestmentTransaction(type: .dividend, quantity: 10, pricePerUnit: 2)
        XCTAssertEqual(dividend.cashImpact, 20)
    }
}
