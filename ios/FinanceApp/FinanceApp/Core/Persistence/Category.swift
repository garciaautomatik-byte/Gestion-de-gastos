import Foundation
import SwiftData

enum CategoryKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
}

@Model
final class Category {
    var id: UUID
    var name: String
    var kind: CategoryKind
    var icon: String
    var colorHex: String
    var isSystemDefault: Bool
    var parentCategory: Category?

    @Relationship(deleteRule: .nullify, inverse: \MoneyTransaction.category)
    var transactions: [MoneyTransaction] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.category)
    var recurringTransactions: [RecurringTransaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        kind: CategoryKind,
        icon: String = "circle.fill",
        colorHex: String = "#8E8E93",
        isSystemDefault: Bool = false,
        parentCategory: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.icon = icon
        self.colorHex = colorHex
        self.isSystemDefault = isSystemDefault
        self.parentCategory = parentCategory
    }
}
