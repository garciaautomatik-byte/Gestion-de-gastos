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

/// Three ready-made presentations each widget can be switched between — from the fullest
/// view down to a glanceable one, independent from show/hide and ordering.
enum DashboardWidgetStyle: String, CaseIterable, Identifiable, Codable {
    case detailed
    case compact
    case card

    var id: String { rawValue }

    var title: String {
        switch self {
        case .detailed: return "Detallado"
        case .compact: return "Compacto"
        case .card: return "Tarjeta"
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
        var styles: [String: String]

        private enum CodingKeys: String, CodingKey { case order, hidden, styles }

        init(order: [String], hidden: [String], styles: [String: String]) {
            self.order = order
            self.hidden = hidden
            self.styles = styles
        }

        // Custom decode so a layout saved before `styles` existed still loads (with an empty
        // styles map) instead of failing decode entirely and silently resetting order/hidden.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            order = try container.decode([String].self, forKey: .order)
            hidden = try container.decode([String].self, forKey: .hidden)
            styles = try container.decodeIfPresent([String: String].self, forKey: .styles) ?? [:]
        }
    }

    static func load() -> (order: [DashboardWidget], hidden: Set<DashboardWidget>, styles: [DashboardWidget: DashboardWidgetStyle]) {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedLayout.self, from: data) else {
            return (DashboardWidget.allCases, [], [:])
        }
        let savedOrder = saved.order.compactMap(DashboardWidget.init(rawValue:))
        // A widget added in a later app version won't be in an already-saved layout — append
        // it visible at the end instead of letting it silently disappear.
        let missing = DashboardWidget.allCases.filter { !savedOrder.contains($0) }
        let hidden = Set(saved.hidden.compactMap(DashboardWidget.init(rawValue:)))
        var styles: [DashboardWidget: DashboardWidgetStyle] = [:]
        for (widgetKey, styleKey) in saved.styles {
            if let widget = DashboardWidget(rawValue: widgetKey), let style = DashboardWidgetStyle(rawValue: styleKey) {
                styles[widget] = style
            }
        }
        return (savedOrder + missing, hidden, styles)
    }

    static func save(order: [DashboardWidget], hidden: Set<DashboardWidget>, styles: [DashboardWidget: DashboardWidgetStyle]) {
        let saved = SavedLayout(
            order: order.map(\.rawValue),
            hidden: hidden.map(\.rawValue),
            styles: Dictionary(uniqueKeysWithValues: styles.map { ($0.key.rawValue, $0.value.rawValue) })
        )
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
