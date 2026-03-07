import Foundation

// MARK: - LegiScan API Response Models

struct FlexibleValue: Codable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            stringValue = str
        } else if let num = try? container.decode(Int.self) {
            stringValue = String(num)
        } else if let num = try? container.decode(Double.self) {
            stringValue = String(num)
        } else {
            stringValue = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

struct LegiScanSearchResponse: Codable {
    let status: FlexibleValue
    let searchresult: SearchResult

    struct SearchResult: Codable {
        let summary: SearchSummary?
        let bills: [String: LegiScanBillSummary]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKey.self)
            var bills: [String: LegiScanBillSummary] = [:]
            var summary: SearchSummary?

            for key in container.allKeys {
                if key.stringValue == "summary" {
                    summary = try container.decode(SearchSummary.self, forKey: key)
                } else if let _ = Int(key.stringValue) {
                    let bill = try container.decode(LegiScanBillSummary.self, forKey: key)
                    bills[key.stringValue] = bill
                }
            }

            self.summary = summary
            self.bills = bills
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            if let summary = summary {
                try container.encode(summary, forKey: DynamicCodingKey(stringValue: "summary"))
            }
            for (key, value) in bills {
                try container.encode(value, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }
}

struct SearchSummary: Codable {
    let page: FlexibleValue?
    let range: FlexibleValue?
    let relevance: FlexibleValue?
    let count: FlexibleValue?
    let page_current: FlexibleValue?
    let page_total: FlexibleValue?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decodeIfPresent(FlexibleValue.self, forKey: .page)
        range = try container.decodeIfPresent(FlexibleValue.self, forKey: .range)
        relevance = try container.decodeIfPresent(FlexibleValue.self, forKey: .relevance)
        count = try container.decodeIfPresent(FlexibleValue.self, forKey: .count)
        page_current = try container.decodeIfPresent(FlexibleValue.self, forKey: .page_current)
        page_total = try container.decodeIfPresent(FlexibleValue.self, forKey: .page_total)
    }

    enum CodingKeys: String, CodingKey {
        case page, range, relevance, count, page_current, page_total
    }
}

struct LegiScanBillSummary: Codable {
    let relevance: Int?
    let state: String?
    let bill_number: String?
    let bill_id: Int
    let change_hash: String?
    let url: String?
    let text_url: String?
    let research_url: String?
    let last_action_date: String?
    let last_action: String?
    let title: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        bill_number = try container.decodeIfPresent(String.self, forKey: .bill_number)
        change_hash = try container.decodeIfPresent(String.self, forKey: .change_hash)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        text_url = try container.decodeIfPresent(String.self, forKey: .text_url)
        research_url = try container.decodeIfPresent(String.self, forKey: .research_url)
        last_action_date = try container.decodeIfPresent(String.self, forKey: .last_action_date)
        last_action = try container.decodeIfPresent(String.self, forKey: .last_action)
        title = try container.decodeIfPresent(String.self, forKey: .title)

        // bill_id can be Int or String
        if let id = try? container.decode(Int.self, forKey: .bill_id) {
            bill_id = id
        } else if let idStr = try? container.decode(String.self, forKey: .bill_id), let id = Int(idStr) {
            bill_id = id
        } else {
            bill_id = 0
        }

        // relevance can be Int or String
        if let rel = try? container.decode(Int.self, forKey: .relevance) {
            relevance = rel
        } else if let relStr = try? container.decode(String.self, forKey: .relevance), let rel = Int(relStr) {
            relevance = rel
        } else {
            relevance = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case relevance, state, bill_number, bill_id, change_hash, url, text_url, research_url, last_action_date, last_action, title
    }
}

struct LegiScanBillDetailResponse: Codable {
    let status: FlexibleValue
    let bill: LegiScanBillDetail
}

struct LegiScanBillDetail: Codable {
    let bill_id: Int
    let state: String
    let bill_number: String
    let title: String
    let description: String?
    let status: Int
    let status_desc: String?
    let url: String
    let state_link: String?
    let session: SessionInfo?
    let sponsors: [Sponsor]?
    let texts: [BillText]?

    struct SessionInfo: Codable {
        let session_id: Int
        let session_name: String
    }

    struct Sponsor: Codable {
        let name: String
        let party: String?
        let role: String?
    }

    struct BillText: Codable {
        let doc_id: Int
        let date: String?
        let type: String?
        let url: String?
    }
}

struct LegiScanSessionListResponse: Codable {
    let status: FlexibleValue
    let sessions: [LegiScanSession]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(FlexibleValue.self, forKey: .status)

        let sessionsContainer = try container.decode([String: LegiScanSession].self, forKey: .sessions)
        sessions = Array(sessionsContainer.values)
    }

    enum CodingKeys: String, CodingKey {
        case status
        case sessions = "sessions"
    }
}

struct LegiScanSession: Codable {
    let session_id: Int
    let state_id: Int
    let session_name: String
}

struct LegiScanMasterListResponse: Codable {
    let status: FlexibleValue
    let masterlist: [String: MasterListBill]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(FlexibleValue.self, forKey: .status)

        let masterContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .masterlist)
        var bills: [String: MasterListBill] = [:]
        for key in masterContainer.allKeys {
            if key.stringValue == "session" { continue }
            if let bill = try? masterContainer.decode(MasterListBill.self, forKey: key) {
                bills[key.stringValue] = bill
            }
        }
        self.masterlist = bills
    }

    enum CodingKeys: String, CodingKey {
        case status
        case masterlist
    }
}

struct MasterListBill: Codable {
    let bill_id: Int
    let number: String?
    let title: String?
    let last_action_date: String?
    let last_action: String?
}

// MARK: - Claude API Models

struct ClaudeRequest: Codable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let content: [ClaudeContent]

    struct ClaudeContent: Codable {
        let type: String
        let text: String?
    }
}

// MARK: - Dynamic Coding Key

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }

    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
