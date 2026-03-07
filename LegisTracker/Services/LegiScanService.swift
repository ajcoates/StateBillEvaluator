import Foundation

actor LegiScanService {
    private let baseURL = "https://api.legiscan.com/"

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "legiScanAPIKey") ?? ""
    }

    func searchBills(query: String, state: String? = nil) async throws -> [LegiScanBillSummary] {
        var params = ["op": "getSearch", "query": query]
        if let state = state, !state.isEmpty {
            params["state"] = state
        }

        let data = try await request(params: params)
        do {
            let response = try JSONDecoder().decode(LegiScanSearchResponse.self, from: data)
            return Array(response.searchresult.bills.values)
        } catch {
            // Log the raw response for debugging
            if let raw = String(data: data, encoding: .utf8) {
                print("LegiScan raw response: \(raw.prefix(2000))")
            }
            print("LegiScan decode error: \(error)")
            throw error
        }
    }

    func getBill(id: Int) async throws -> LegiScanBillDetail {
        let params = ["op": "getBill", "id": String(id)]
        let data = try await request(params: params)
        let response = try JSONDecoder().decode(LegiScanBillDetailResponse.self, from: data)
        return response.bill
    }

    func getSessionList(state: String) async throws -> [LegiScanSession] {
        let params = ["op": "getSessionList", "state": state]
        let data = try await request(params: params)
        let response = try JSONDecoder().decode(LegiScanSessionListResponse.self, from: data)
        return response.sessions
    }

    func getMasterList(sessionId: Int) async throws -> [MasterListBill] {
        let params = ["op": "getMasterList", "id": String(sessionId)]
        let data = try await request(params: params)
        let response = try JSONDecoder().decode(LegiScanMasterListResponse.self, from: data)
        return Array(response.masterlist.values)
    }

    private func request(params: [String: String]) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw LegiScanError.missingAPIKey
        }

        var components = URLComponents(string: baseURL)!
        var queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        components.queryItems = queryItems

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LegiScanError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LegiScanError.httpError(httpResponse.statusCode)
        }

        return data
    }
}

enum LegiScanError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "LegiScan API key is not configured. Set it in Settings."
        case .invalidResponse:
            return "Invalid response from LegiScan API."
        case .httpError(let code):
            return "LegiScan API returned HTTP \(code)."
        }
    }
}
