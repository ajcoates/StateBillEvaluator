import Foundation
import SwiftData

@Model
final class Bill {
    @Attribute(.unique) var billId: Int
    var title: String
    var billDescription: String
    var state: String
    var status: String
    var session: String
    var url: String
    var categoryName: String?
    var lastUpdated: Date
    var billText: String?
    var sponsors: String?
    var lastAction: String?
    var lastActionDate: String?
    var impactAnalysisJSON: String?

    @Relationship(inverse: \BillCategory.bills)
    var category: BillCategory?

    enum PassageLikelihood: String, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case passed = "Passed"
        case dead = "Dead"

        var color: String {
            switch self {
            case .low: return "red"
            case .medium: return "yellow"
            case .high: return "green"
            case .passed: return "blue"
            case .dead: return "gray"
            }
        }
    }

    var passageLikelihood: PassageLikelihood {
        let s = status.lowercased()
        let action = (lastAction ?? "").lowercased()

        // Check for dead/failed bills
        if s.contains("vetoed") || s.contains("failed") || action.contains("failed") || action.contains("vetoed") || action.contains("died") || action.contains("tabled") {
            return .dead
        }

        // Check for passed/enacted bills
        if s.contains("enacted") || s.contains("signed") || s.contains("chaptered") || action.contains("signed by governor") || action.contains("enacted") {
            return .passed
        }

        // Check for high likelihood — passed at least one chamber
        if s.contains("passed") || s.contains("enrolled") || action.contains("passed senate") || action.contains("passed house") || action.contains("passed assembly") || s.contains("engrossed") {
            return .high
        }

        // Medium — active in committee or has meaningful progress
        if s.contains("committee") || action.contains("committee") || action.contains("referred") || action.contains("hearing") || action.contains("amended") {
            return .medium
        }

        // Default — just introduced
        return .low
    }

    init(
        billId: Int,
        title: String,
        billDescription: String,
        state: String,
        status: String,
        session: String,
        url: String,
        categoryName: String? = nil,
        lastUpdated: Date = .now,
        billText: String? = nil,
        sponsors: String? = nil,
        lastAction: String? = nil,
        lastActionDate: String? = nil
    ) {
        self.billId = billId
        self.title = title
        self.billDescription = billDescription
        self.state = state
        self.status = status
        self.session = session
        self.url = url
        self.categoryName = categoryName
        self.lastUpdated = lastUpdated
        self.billText = billText
        self.sponsors = sponsors
        self.lastAction = lastAction
        self.lastActionDate = lastActionDate
    }
}
