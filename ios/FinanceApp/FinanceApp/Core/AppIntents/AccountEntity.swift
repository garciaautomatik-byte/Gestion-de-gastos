import AppIntents
import Foundation
import SwiftData

struct AccountEntity: AppEntity {
    let id: UUID
    let name: String
    let currency: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Cuenta"
    static let defaultQuery = AccountEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct AccountEntityQuery: EntityQuery, EnumerableEntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [AccountEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }

    /// Investment-only accounts are excluded — a "movimiento" here is a bank transaction
    /// (checking/savings/card), matching what AddTransactionView offers.
    func allEntities() async throws -> [AccountEntity] {
        let context = ModelContext(AppModelContainer.shared)
        let accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
        return accounts
            .filter { $0.type != .investmentManual }
            .map { AccountEntity(id: $0.id, name: $0.name, currency: $0.currency) }
    }
}
