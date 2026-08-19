import Foundation
import SwiftData

enum DefaultCategories {
    static let expense: [(name: String, icon: String, colorHex: String)] = [
        ("Alimentación", "cart.fill", "#34C759"),
        ("Transporte", "car.fill", "#007AFF"),
        ("Vivienda", "house.fill", "#FF9500"),
        ("Ocio", "gamecontroller.fill", "#AF52DE"),
        ("Salud", "cross.case.fill", "#FF3B30"),
        ("Compras", "bag.fill", "#5AC8FA"),
        ("Restaurantes", "fork.knife", "#FF2D55"),
        ("Suscripciones", "arrow.triangle.2.circlepath", "#8E8E93"),
        ("Otros gastos", "ellipsis.circle.fill", "#636366")
    ]

    static let income: [(name: String, icon: String, colorHex: String)] = [
        ("Nómina", "banknote.fill", "#34C759"),
        ("Freelance", "briefcase.fill", "#007AFF"),
        ("Inversiones", "chart.line.uptrend.xyaxis", "#AF52DE"),
        ("Otros ingresos", "plus.circle.fill", "#636366")
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.isSystemDefault == true })
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for item in expense {
            context.insert(Category(name: item.name, kind: .expense, icon: item.icon, colorHex: item.colorHex, isSystemDefault: true))
        }
        for item in income {
            context.insert(Category(name: item.name, kind: .income, icon: item.icon, colorHex: item.colorHex, isSystemDefault: true))
        }
        try? context.save()
    }
}
