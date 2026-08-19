# Gestión de gastos

App personal de gestión financiera para iOS: gastos, ingresos, movimientos e inversiones de varios bancos españoles.

Ver el plan completo en `docs/architecture.md` y `docs/data-model.md`.

## Estado actual

**Fase 1 (en curso):** app iOS local con SwiftData, sin backend. Entrada manual de cuentas, movimientos e inversiones.

## Abrir el proyecto

```
cd ios/FinanceApp
xcodegen generate   # regenera FinanceApp.xcodeproj a partir de project.yml tras cambiar archivos
open FinanceApp.xcodeproj
```

El proyecto usa [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) para generar el `.xcodeproj` a partir de `ios/FinanceApp/project.yml`, en vez de commitear el `.xcodeproj` directamente. Tras añadir/quitar/mover archivos Swift, vuelve a correr `xcodegen generate`.

## Compilar y testear desde terminal

```
cd ios/FinanceApp
xcodebuild -project FinanceApp.xcodeproj -scheme FinanceApp -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project FinanceApp.xcodeproj -scheme FinanceApp -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Notas importantes

- Los tests usan **XCTest**, no Swift Testing (`@Test`): en Xcode 26.5 / Swift 6.3 se detectó un crash reproducible de SwiftData con Swift Testing. Ver comentario en `ios/FinanceApp/FinanceAppTests/HoldingTests.swift`.
- El modelo de movimiento bancario se llama `MoneyTransaction`, no `Transaction`: nombrarlo `Transaction` provocaba un crash de SwiftData al insertar (colisión con otro tipo `Transaction` del sistema). Ver comentario en `ios/FinanceApp/FinanceApp/Core/Persistence/MoneyTransaction.swift`.
- Instalación en el propio iPhone: por ahora vía Xcode con firma gratuita (el provisioning expira cada 7 días). No hay cuenta de Apple Developer configurada todavía.
