import SwiftUI
import SwiftData

@main
struct LegisTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                MainView()
                    .tabItem {
                        Label("Legislation", systemImage: "doc.text")
                    }

                CompanyRankingsView()
                    .tabItem {
                        Label("Company Rankings", systemImage: "building.2")
                    }
            }
        }
        .modelContainer(for: [Bill.self, BillCategory.self])

        Settings {
            SettingsView()
        }
    }
}
