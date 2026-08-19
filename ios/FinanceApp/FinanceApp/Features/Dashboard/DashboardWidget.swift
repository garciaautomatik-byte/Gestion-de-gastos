import Foundation

enum DashboardWidget: String, CaseIterable, Identifiable, Codable {
    case balance
    case monthlyChart
    case investments
    case categorySpending
    case recentTransactions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balance: return "Saldo total"
        case .monthlyChart: return "Ingresos y gastos por mes"
        case .investments: return "Inversiones"
        case .categorySpending: return "Gasto por categoría"
        case .recentTransactions: return "Movimientos recientes"
        }
    }

    var icon: String {
        switch self {
        case .balance: return "eurosign.circle.fill"
        case .monthlyChart: return "chart.bar.fill"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .categorySpending: return "chart.pie.fill"
        case .recentTransactions: return "list.bullet"
        }
    }
}

/// Persists which dashboard sections are shown and in what order. Plain UserDefaults rather
/// than SwiftData — this is a device-local display preference, not app data worth syncing
/// through the backup export/import feature.
enum DashboardLayoutStore {
    private static let key = "dashboardLayout.v1"

    private struct SavedLayout: Codable {
        var order: [String]
        var hidden: [String]
    }

    static func load() -> (order: [DashboardWidget], hidden: Set<DashboardWidget>) {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedLayout.self, from: data) else {
            return (DashboardWidget.allCases, [])
        }
        let savedOrder = saved.order.compactMap(DashboardWidget.init(rawValue:))
        // A widget added in a later app version won't be in an already-saved layout — append
        // it visible at the end instead of letting it silently disappear.
        let missing = DashboardWidget.allCases.filter { !savedOrder.contains($0) }
        let hidden = Set(saved.hidden.compactMap(DashboardWidget.init(rawValue:)))
        return (savedOrder + missing, hidden)
    }

    static func save(order: [DashboardWidget], hidden: Set<DashboardWidget>) {
        let saved = SavedLayout(order: order.map(\.rawValue), hidden: hidden.map(\.rawValue))
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
