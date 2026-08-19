import AppIntents

/// Lets Shortcuts/Siri present the app's existing `CategoryKind` (defined in
/// Core/Persistence/Category.swift) as a "Gasto / Ingreso" picker, without adding an
/// App-Intents-specific duplicate of the enum.
extension CategoryKind: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tipo de movimiento"

    static let caseDisplayRepresentations: [CategoryKind: DisplayRepresentation] = [
        .expense: "Gasto",
        .income: "Ingreso"
    ]
}
