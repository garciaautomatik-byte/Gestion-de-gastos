import Foundation
import SwiftData

/// A single shared container, instead of letting `.modelContainer(for:)` create an implicit one.
/// App Intents (Core/AppIntents) can run in a background launch of the app process — triggered
/// from Siri/Shortcuts without the UI ever appearing — and need a reference to the same store
/// the app itself uses.
enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Account.self, MoneyTransaction.self, Category.self, Holding.self, InvestmentTransaction.self, RecurringTransaction.self])
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
}
