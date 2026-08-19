# Modelo de datos (Fase 1)

Fuente de verdad: `ios/FinanceApp/FinanceApp/Core/Persistence/*.swift`. Este documento es un resumen; si hay discrepancia, el código manda.

| Modelo | Campos clave | Relaciones |
|---|---|---|
| `Account` | `name`, `type` (checking/savings/creditCard/investmentManual), `currentBalance`, `currency`, `isManual` | `transactions: [MoneyTransaction]` (cascade), `holdings: [Holding]` (cascade) |
| `MoneyTransaction` | `amount`, `currency`, `date`, `transactionDescription`, `merchantName?`, `isPending`, `externalId?` (para dedup en Fase 2), `source` (manual/synced) | `account: Account?`, `category: Category?` |
| `Category` | `name`, `kind` (expense/income), `icon`, `colorHex`, `isSystemDefault` | `parentCategory: Category?`, `transactions: [MoneyTransaction]` (nullify) |
| `Holding` | `ticker`, `name`, `assetType` (stock/etf/fund/crypto/other), `currency` | `account: Account?`, `investmentTransactions: [InvestmentTransaction]` (cascade). Calcula `quantity`, `totalCost`, `averageCost` a partir del ledger. |
| `InvestmentTransaction` | `type` (buy/sell/dividend), `quantity`, `pricePerUnit`, `date`, `fees` | `holding: Holding?` |

Categorías por defecto: ver `Core/Persistence/DefaultCategories.swift` (se siembran una vez al arrancar la app, marcadas `isSystemDefault: true`).

## Pendiente para Fase 2/3 (no implementado aún)

- `BankConnection` (Fase 2): banco, id de institución, estado de consentimiento, expiración.
- `CategoryRule` (Fase 3): reglas de auto-categorización.
- `Budget` (Fase 3): presupuestos por categoría/periodo.

Cuando el backend (Supabase/Postgres) exista en Fase 2, sus tablas deben reflejar estos mismos modelos.
