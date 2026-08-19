import AppIntents

/// Registering this makes `AddTransactionIntent` show up as a ready-made shortcut in the
/// Shortcuts app (with this app's icon) and as a Siri phrase — no manual shortcut-building
/// required. From there it can be added to the Home Screen, the Action Button, or a Lock
/// Screen widget like any other shortcut icon.
struct FinanceAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: [
                "Añade un gasto en \(.applicationName)",
                "Añade un movimiento en \(.applicationName)",
                "Registra un gasto en \(.applicationName)",
                "Registra un ingreso en \(.applicationName)"
            ],
            shortTitle: "Añadir movimiento",
            systemImageName: "plus.circle"
        )
    }
}
