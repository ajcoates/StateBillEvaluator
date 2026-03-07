import Foundation

struct ImpactAnalysis: Codable {
    let winners: [ImpactEntry]
    let losers: [ImpactEntry]
}

struct ImpactEntry: Codable, Identifiable {
    let industry: String
    let companies: [String]
    let reason: String

    var id: String { industry }
}
