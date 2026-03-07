import SwiftUI
import SwiftData

struct SidebarView: View {
    @Bindable var viewModel: LegislationViewModel
    @Query(sort: \BillCategory.name) private var categories: [BillCategory]
    @Query private var allBills: [Bill]

    var body: some View {
        List(selection: $viewModel.selectedCategoryName) {
            Section {
                Label("All Bills (\(allBills.count))", systemImage: "doc.text")
                    .tag(nil as String?)
            }

            Section("Categories") {
                ForEach(categoriesWithBills, id: \.name) { category in
                    Label("\(category.name) (\(category.billCount))", systemImage: iconForCategory(category.name))
                        .tag(category.name as String?)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("State Bill Evaluator")
    }

    private var categoriesWithBills: [BillCategory] {
        categories.filter { $0.billCount > 0 }
    }

    private func iconForCategory(_ name: String) -> String {
        switch name {
        case "Healthcare": return "heart.text.square"
        case "Education": return "book"
        case "Criminal Justice": return "building.columns"
        case "Taxation": return "dollarsign.circle"
        case "Environment": return "leaf"
        case "Elections": return "checkmark.seal"
        case "Housing": return "house"
        case "Labor": return "person.2"
        case "Technology & Privacy": return "lock.shield"
        case "Transportation": return "car"
        case "Agriculture": return "carrot"
        case "Energy": return "bolt"
        case "Gun Policy": return "exclamationmark.shield"
        case "Immigration": return "globe"
        case "Budget & Appropriations": return "banknote"
        default: return "doc"
        }
    }
}
