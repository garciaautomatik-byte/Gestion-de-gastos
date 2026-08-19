# Arquitectura

Ver el plan completo en `/Users/minigarci/.claude/plans/me-gustaia-crear-algo-memoized-snail.md` para el contexto y las decisiones de diseño (agregador Open Banking, backend, fases de construcción).

## Fase 1 (actual): app iOS local, sin backend

- **SwiftUI + MVVM**, target mínimo iOS 17.
- **SwiftData** como única persistencia (sin backend todavía). `FinanceAppApp.swift` crea el `ModelContainer` para los 5 modelos; `RootView.swift` es el `TabView` raíz con 4 pestañas (Resumen, Cuentas, Movimientos, Inversiones).
- Estructura de carpetas: `App/`, `Features/<Dashboard|Accounts|Transactions|Investments|Budgets|BankLinking>/`, `Core/<Persistence|Networking|Security|DesignSystem>/`.
  - `Features/Budgets` y `Features/BankLinking` están vacías: son para Fase 3 y Fase 2 respectivamente.
  - `Core/Networking` y `Core/Security` están vacías: son para cuando exista el backend (Fase 2).

## Fase 2 (futura): backend + Open Banking

Ver `docs/open-banking-notes.md` (se irá completando banco a banco cuando se aborde esta fase) y la sección "Backend (Fase 2, Supabase)" del plan.

## Decisiones de nombres que difieren de lo obvio

- El modelo de movimiento bancario se llama **`MoneyTransaction`**, no `Transaction`. Nombrarlo `Transaction` provocaba un crash reproducible de SwiftData (`EXC_BREAKPOINT`) al insertar el primer registro, en Xcode 26.5 / Swift 6.3. Ver el comentario en `ios/FinanceApp/FinanceApp/Core/Persistence/MoneyTransaction.swift`.
- La propiedad de texto libre de una transacción se llama `transactionDescription`, no `description`: en una clase `@Model` de SwiftData, `description` choca con `CustomStringConvertible`.
