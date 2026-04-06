import SwiftUI
import SwiftData

struct CompanyRankingsView: View {
    @Query private var allBills: [Bill]
    @State private var activeCategories: Set<String> = Set(BillCategory.predefinedCategories)
    @State private var companyScaleFilter: CompanyScaleFilter = .all
    @State private var sortOrder: RankingSortOrder = .score

    enum CompanyScaleFilter: String, CaseIterable {
        case all = "All Companies"
        case localRegional = "Local & Regional"
        case nationalGlobal = "National & Global"
    }

    enum RankingSortOrder: String, CaseIterable {
        case score = "Weighted Score"
        case billCount = "Number of Bills"
    }

    private var rankings: (gainers: [CompanyRanking], losers: [CompanyRanking]) {
        var gainerCounts: [String: CompanyRanking] = [:]
        var loserCounts: [String: CompanyRanking] = [:]

        let filteredBills = allBills.filter { bill in
            guard let cat = bill.categoryName else { return false }
            return activeCategories.contains(cat) && bill.passageLikelihood != .passed
        }

        for bill in filteredBills {
            guard let json = bill.impactAnalysisJSON,
                  let data = json.data(using: .utf8),
                  let analysis = try? JSONDecoder().decode(ImpactAnalysis.self, from: data) else {
                continue
            }

            let weight = CompanyRanking.weight(for: bill.passageLikelihood)

            let billLink = (title: bill.title, url: bill.url)

            for entry in analysis.winners {
                for detail in entry.resolvedDetails {
                    let key = detail.name.lowercased()
                    if var existing = gainerCounts[key] {
                        existing.count += 1
                        existing.score += weight
                        existing.industries.insert(entry.industry)
                        existing.billLinks.append(billLink)
                        if existing.ticker == nil { existing.ticker = detail.ticker }
                        if existing.parentCompany == nil { existing.parentCompany = detail.parentCompany }
                        if existing.parentTicker == nil { existing.parentTicker = detail.parentTicker }
                        gainerCounts[key] = existing
                    } else {
                        gainerCounts[key] = CompanyRanking(
                            name: detail.name,
                            count: 1,
                            score: weight,
                            industries: [entry.industry],
                            billLinks: [billLink],
                            isLargeCap: detail.isLargeCap,
                            ticker: detail.ticker,
                            parentCompany: detail.parentCompany,
                            parentTicker: detail.parentTicker
                        )
                    }
                }
            }

            for entry in analysis.losers {
                for detail in entry.resolvedDetails {
                    let key = detail.name.lowercased()
                    if var existing = loserCounts[key] {
                        existing.count += 1
                        existing.score += weight
                        existing.industries.insert(entry.industry)
                        existing.billLinks.append(billLink)
                        if existing.ticker == nil { existing.ticker = detail.ticker }
                        if existing.parentCompany == nil { existing.parentCompany = detail.parentCompany }
                        if existing.parentTicker == nil { existing.parentTicker = detail.parentTicker }
                        loserCounts[key] = existing
                    } else {
                        loserCounts[key] = CompanyRanking(
                            name: detail.name,
                            count: 1,
                            score: weight,
                            industries: [entry.industry],
                            billLinks: [billLink],
                            isLargeCap: detail.isLargeCap,
                            ticker: detail.ticker,
                            parentCompany: detail.parentCompany,
                            parentTicker: detail.parentTicker
                        )
                    }
                }
            }
        }

        let filterGainers: [CompanyRanking]
        let filterLosers: [CompanyRanking]

        switch companyScaleFilter {
        case .all:
            filterGainers = Array(gainerCounts.values)
            filterLosers = Array(loserCounts.values)
        case .localRegional:
            filterGainers = gainerCounts.values.filter { !$0.isLargeCap }
            filterLosers = loserCounts.values.filter { !$0.isLargeCap }
        case .nationalGlobal:
            filterGainers = gainerCounts.values.filter { $0.isLargeCap }
            filterLosers = loserCounts.values.filter { $0.isLargeCap }
        }

        let sorter: (CompanyRanking, CompanyRanking) -> Bool
        switch sortOrder {
        case .score:
            sorter = { $0.score > $1.score }
        case .billCount:
            sorter = { $0.count > $1.count }
        }
        let sortedGainers = filterGainers.sorted(by: sorter)
        let sortedLosers = filterLosers.sorted(by: sorter)
        return (sortedGainers, sortedLosers)
    }

    var body: some View {
        HSplitView {
            // Category filter sidebar
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Filter Categories", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.headline)
                    Spacer()
                }
                .padding()

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Button("All") {
                                activeCategories = Set(BillCategory.predefinedCategories)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("None") {
                                activeCategories.removeAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.bottom, 4)

                        ForEach(BillCategory.predefinedCategories, id: \.self) { category in
                            Toggle(isOn: Binding(
                                get: { activeCategories.contains(category) },
                                set: { isOn in
                                    if isOn {
                                        activeCategories.insert(category)
                                    } else {
                                        activeCategories.remove(category)
                                    }
                                }
                            )) {
                                Text(category)
                                    .font(.callout)
                            }
                            .toggleStyle(.checkbox)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        Text("Company Size")
                            .font(.headline)
                            .padding(.bottom, 4)

                        Picker("Scale", selection: $companyScaleFilter) {
                            ForEach(CompanyScaleFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        Divider()
                            .padding(.vertical, 8)

                        Text("Sort By")
                            .font(.headline)
                            .padding(.bottom, 4)

                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(RankingSortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                    .padding()
                }
            }
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)

            // Rankings content
            VStack(spacing: 0) {
                // Weighting explanation
                HStack(spacing: 16) {
                    Text("Predictive scores (passed bills excluded):")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach([
                        ("High", 0.75, Color.green),
                        ("Medium", 0.50, Color.yellow),
                        ("Low", 0.25, Color.red),
                        ("Dead", 0.05, Color.gray)
                    ], id: \.0) { label, weight, color in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                            Text("\(label) = \(String(format: "%.2f", weight))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.bar)

                Divider()

            HStack(spacing: 0) {
                // Gainers
                RankingColumn(
                    title: "Most to Gain",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    rankings: rankings.gainers
                )

                Divider()

                // Losers
                RankingColumn(
                    title: "Most at Risk",
                    icon: "chart.line.downtrend.xyaxis",
                    color: .red,
                    rankings: rankings.losers
                )
            }
            }
        }
    }
}

struct CompanyRanking: Identifiable {
    let name: String
    var count: Int
    var score: Double
    var industries: Set<String>
    var billLinks: [(title: String, url: String)]
    var isLargeCap: Bool
    var ticker: String?
    var parentCompany: String?
    var parentTicker: String?

    var id: String { name.lowercased() }

    static func weight(for likelihood: Bill.PassageLikelihood) -> Double {
        switch likelihood {
        case .passed: return 1.0
        case .high: return 0.75
        case .medium: return 0.5
        case .low: return 0.25
        case .dead: return 0.05
        }
    }
}

struct RankingColumn: View {
    let title: String
    let icon: String
    let color: Color
    let rankings: [CompanyRanking]
    @State private var expandedCompanies: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                Spacer()
                Text("\(rankings.count) companies")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            if rankings.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "building.2")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No company data yet.\nRun Impact Analysis on bills to populate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(rankings.enumerated()), id: \.element.id) { index, company in
                            HStack(alignment: .top, spacing: 10) {
                                Text("#\(index + 1)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(color.opacity(0.7))
                                    .frame(width: 36, alignment: .trailing)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(company.name)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                        if let ticker = company.ticker {
                                            Text(ticker)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.secondary.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                        if company.ticker == nil, let parent = company.parentCompany {
                                            let label = if let pt = company.parentTicker { "Subsidiary of \(parent) (\(pt))" } else { "Subsidiary of \(parent)" }
                                            Text(label)
                                                .font(.caption2)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange)
                                                .clipShape(Capsule())
                                        }
                                        Spacer()
                                        Text(String(format: "%.2f", company.score))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(color.opacity(0.15))
                                            .foregroundStyle(color)
                                            .clipShape(Capsule())
                                            .help("Weighted score based on passage likelihood")
                                        HStack(spacing: 2) {
                                            Text("\(company.count) bill\(company.count == 1 ? "" : "s")")
                                            Image(systemName: expandedCompanies.contains(company.id) ? "chevron.up" : "chevron.down")
                                                .imageScale(.small)
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.secondary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if expandedCompanies.contains(company.id) {
                                                    expandedCompanies.remove(company.id)
                                                } else {
                                                    expandedCompanies.insert(company.id)
                                                }
                                            }
                                        }
                                    }

                                    HStack(spacing: 4) {
                                        ForEach(Array(company.industries).sorted(), id: \.self) { industry in
                                            Text(industry)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.quaternary)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                    }

                                    if expandedCompanies.contains(company.id) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            ForEach(Array(company.billLinks.enumerated()), id: \.offset) { _, bill in
                                                HStack(alignment: .top, spacing: 6) {
                                                    Text("\u{2022}")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                    if let url = URL(string: bill.url), !bill.url.isEmpty {
                                                        Link(destination: url) {
                                                            Text(bill.title)
                                                                .font(.caption)
                                                                .foregroundStyle(.blue)
                                                                .lineLimit(2)
                                                                .underline()
                                                        }
                                                    } else {
                                                        Text(bill.title)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(2)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
