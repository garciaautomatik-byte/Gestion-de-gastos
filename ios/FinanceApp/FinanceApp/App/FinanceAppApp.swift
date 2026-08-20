import SwiftUI
import SwiftData

@main
struct FinanceAppApp: App {
    init() {
        // Every List/Form in the app is backed by UITableView — one appearance override tints
        // all of them dark green instead of the system's neutral near-black, matching the
        // reference app's theme without touching every screen individually.
        UITableView.appearance().backgroundColor = UIColor(Color.appBackground)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(AppModelContainer.shared)
    }
}
