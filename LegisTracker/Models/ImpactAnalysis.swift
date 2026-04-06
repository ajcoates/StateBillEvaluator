import Foundation

struct ImpactAnalysis: Codable {
    let winners: [ImpactEntry]
    let losers: [ImpactEntry]
}

struct ImpactEntry: Codable, Identifiable {
    let industry: String
    let companies: [String]
    let reason: String
    let company_details: [CompanyDetail]?

    var id: String { industry }

    // Backwards compatible: get details or fall back to names only
    var resolvedDetails: [CompanyDetail] {
        if let details = company_details, !details.isEmpty {
            return details
        }
        return companies.map { CompanyDetail(name: $0, scale: CompanyDetail.classifyFallback($0), ticker: nil) }
    }
}

struct CompanyDetail: Codable, Identifiable {
    let name: String
    let scale: String // "local", "regional", "national", "global"
    let ticker: String?
    let parentCompany: String?
    let parentTicker: String?

    var id: String { name }

    init(name: String, scale: String, ticker: String? = nil, parentCompany: String? = nil, parentTicker: String? = nil) {
        self.name = name
        self.scale = scale
        self.ticker = ticker
        self.parentCompany = parentCompany
        self.parentTicker = parentTicker
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        scale = try container.decode(String.self, forKey: .scale)
        ticker = try container.decodeIfPresent(String.self, forKey: .ticker)
        parentCompany = try container.decodeIfPresent(String.self, forKey: .parentCompany)
        parentTicker = try container.decodeIfPresent(String.self, forKey: .parentTicker)
    }

    private enum CodingKeys: String, CodingKey {
        case name, scale, ticker
        case parentCompany = "parent_company"
        case parentTicker = "parent_ticker"
    }

    var isLargeCap: Bool {
        scale == "national" || scale == "global"
    }

    // Fallback classification for analyses that don't include scale
    static func classifyFallback(_ name: String) -> String {
        let megaCaps = [
            "amazon", "apple", "google", "alphabet", "microsoft", "meta",
            "facebook", "walmart", "target", "costco", "home depot",
            "jpmorgan", "bank of america", "wells fargo", "citigroup",
            "unitedhealth", "johnson & johnson", "pfizer", "merck",
            "exxonmobil", "chevron", "shell", "bp",
            "tesla", "ford", "general motors", "toyota",
            "at&t", "verizon", "comcast", "disney",
            "coca-cola", "pepsico", "procter & gamble", "nike",
            "berkshire hathaway", "visa", "mastercard", "paypal",
            "nvidia", "intel", "amd", "broadcom",
            "netflix", "uber", "airbnb", "salesforce",
            "boeing", "lockheed martin", "raytheon",
            "caterpillar", "deere", "3m",
            "cvs", "walgreens", "anthem", "cigna", "humana",
            "kroger", "starbucks", "mcdonald's",
            "fedex", "ups", "delta", "united airlines", "american airlines",
            "goldman sachs", "morgan stanley", "charles schwab",
            "aetna", "blue cross", "kaiser permanente",
            "nordvpn", "expressvpn"
        ]
        let lower = name.lowercased()
        for megaCap in megaCaps {
            if lower.contains(megaCap) {
                return "global"
            }
        }
        return "regional"
    }
}
