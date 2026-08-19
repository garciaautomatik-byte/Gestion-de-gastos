import AppIntents
import Foundation
import SwiftData

struct CategoryEntity: AppEntity {
    // Shortcuts doesn't reliably offer an "Ask Each Time" toggle for *optional* custom
    // AppEntity parameters (unlike required ones, e.g. AccountEntity) — the field silently
    // never prompts. Modeling "no category" as a real, selectable entity instead of `nil`
    // sidesteps that by making the parameter required, same as account/type/amount.
    static let noCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let noCategory = CategoryEntity(id: noCategoryID, name: "Sin categoría", kind: nil)

    let id: UUID
    let name: String
    let kind: CategoryKind?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Categoría"
    static let defaultQuery = CategoryEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        guard let kind else { return DisplayRepresentation(title: "\(name)") }
        return DisplayRepresentation(title: "\(name)", subtitle: kind == .expense ? "Gasto" : "Ingreso")
    }
}

struct CategoryEntityQuery: EntityQuery, EnumerableEntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CategoryEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }

    func allEntities() async throws -> [CategoryEntity] {
        let context = ModelContext(AppModelContainer.shared)
        let categories = try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)]))
        return [CategoryEntity.noCategory] + categories.map { CategoryEntity(id: $0.id, name: $0.name, kind: $0.kind) }
    }
}
