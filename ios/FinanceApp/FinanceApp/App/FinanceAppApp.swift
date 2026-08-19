import SwiftUI
import SwiftData

@main
struct FinanceAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppModelContainer.shared)
    }
}
