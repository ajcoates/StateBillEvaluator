import Foundation

actor ClaudeService {
    private let baseURL = "https://api.anthropic.com/v1/messages"

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
    }

    func categorizeBill(title: String, description: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        let categories = BillCategory.predefinedCategories.joined(separator: ", ")

        let prompt = """
        Categorize the following legislation bill into exactly one of these categories:
        \(categories)

        Bill Title: \(title)
        Bill Description: \(description)

        Respond with ONLY the category name, nothing else. The category must exactly match one from the list above.
        """

        let requestBody = ClaudeRequest(
            model: "claude-sonnet-4-5-20250929",
            max_tokens: 50,
            messages: [ClaudeMessage(role: "user", content: prompt)]
        )

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClaudeError.httpError(httpResponse.statusCode)
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let text = claudeResponse.content.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ClaudeError.noContent
        }

        // Validate the returned category matches a predefined one
        if BillCategory.predefinedCategories.contains(text) {
            return text
        }

        // Try fuzzy match
        for category in BillCategory.predefinedCategories {
            if text.localizedCaseInsensitiveContains(category) || category.localizedCaseInsensitiveContains(text) {
                return category
            }
        }

        // Default fallback
        return text
    }

    func analyzeImpact(title: String, description: String) async throws -> ImpactAnalysis {
        guard !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        let prompt = """
        Analyze the following legislation and identify industries and companies that would benefit (winners) or be negatively affected (losers) if this bill passes.

        Bill Title: \(title)
        Bill Description: \(description)

        Respond with ONLY valid JSON in this exact format, no other text:
        {
          "winners": [
            {"industry": "Industry Name", "companies": ["Company1", "Company2"], "company_details": [{"name": "Company1", "scale": "global"}, {"name": "Company2", "scale": "regional"}], "reason": "Brief explanation"}
          ],
          "losers": [
            {"industry": "Industry Name", "companies": ["Company1", "Company2"], "company_details": [{"name": "Company1", "scale": "national"}, {"name": "Company2", "scale": "local"}], "reason": "Brief explanation"}
          ]
        }

        For "scale", use one of: "local" (single city/county), "regional" (multi-state or single state), "national" (US-wide), or "global" (multinational).

        Include 2-4 entries for each of winners and losers. List 1-3 well-known public companies per industry where applicable, including a mix of large and smaller regional companies when relevant. If no specific companies are relevant, use empty arrays for companies and company_details.
        """

        let requestBody = ClaudeRequest(
            model: "claude-sonnet-4-5-20250929",
            max_tokens: 1000,
            messages: [ClaudeMessage(role: "user", content: prompt)]
        )

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClaudeError.httpError(httpResponse.statusCode)
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let text = claudeResponse.content.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ClaudeError.noContent
        }

        // Strip markdown code fences if present
        var jsonString = text
        if jsonString.hasPrefix("```") {
            // Remove opening fence (```json or ```)
            if let firstNewline = jsonString.firstIndex(of: "\n") {
                jsonString = String(jsonString[jsonString.index(after: firstNewline)...])
            }
            // Remove closing fence
            if jsonString.hasSuffix("```") {
                jsonString = String(jsonString.dropLast(3))
            }
            jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Parse the JSON response
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeError.noContent
        }

        do {
            return try JSONDecoder().decode(ImpactAnalysis.self, from: jsonData)
        } catch {
            print("Impact analysis JSON: \(jsonString.prefix(1000))")
            print("Impact analysis decode error: \(error)")
            throw error
        }
    }

    func chat(messages: [ClaudeMessage], systemPrompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        var body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 1024,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]

        if let systemPrompt {
            body["system"] = systemPrompt
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClaudeError.httpError(httpResponse.statusCode)
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let text = claudeResponse.content.first?.text else {
            throw ClaudeError.noContent
        }

        return text
    }

    func categorizeBills(_ bills: [(title: String, description: String)]) async throws -> [String] {
        var results: [String] = []
        for bill in bills {
            let category = try await categorizeBill(title: bill.title, description: bill.description)
            results.append(category)
            // Small delay between requests to respect rate limits
            try await Task.sleep(for: .milliseconds(200))
        }
        return results
    }
}

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(Int)
    case noContent

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is not configured. Set it in Settings."
        case .invalidResponse:
            return "Invalid response from Claude API."
        case .httpError(let code):
            return "Claude API returned HTTP \(code)."
        case .noContent:
            return "Claude API returned no content."
        }
    }
}
