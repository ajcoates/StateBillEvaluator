import SwiftUI
import SwiftData

@main
struct LegisTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(for: [Bill.self, BillCategory.self])

        Settings {
            SettingsView()
        }
    }
}
