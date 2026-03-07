import Foundation
import SwiftData

@Model
final class BillCategory {
    @Attribute(.unique) var name: String
    var bills: [Bill]?

    var billCount: Int {
        bills?.count ?? 0
    }

    init(name: String) {
        self.name = name
        self.bills = []
    }

    static let predefinedCategories = [
        "Healthcare",
        "Education",
        "Criminal Justice",
        "Taxation",
        "Environment",
        "Elections",
        "Housing",
        "Labor",
        "Technology & Privacy",
        "Transportation",
        "Agriculture",
        "Energy",
        "Gun Policy",
        "Immigration",
        "Budget & Appropriations"
    ]
}
