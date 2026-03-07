import SwiftUI
import SwiftData

struct CompanyRankingsView: View {
    @Query private var allBills: [Bill]
    @State private var activeCategories: Set<String> = Set(BillCategory.predefinedCategories)

    private var rankings: (gainers: [CompanyRanking], losers: [CompanyRanking]) {
        var gainerCounts: [String: CompanyRanking] = [:]
        var loserCounts: [String: CompanyRanking] = [:]

        let filteredBills = allBills.filter { bill in
            guard let cat = bill.categoryName else { return false }
            return activeCategories.contains(cat)
        }

        for bill in filteredBills {
            guard let json = bill.impactAnalysisJSON,
                  let data = json.data(using: .utf8),
                  let analysis = try? JSONDecoder().decode(ImpactAnalysis.self, from: data) else {
                continue
            }

            for entry in analysis.winners {
                for company in entry.companies {
                    let key = company.lowercased()
                    if var existing = gainerCounts[key] {
                        existing.count += 1
                        existing.industries.insert(entry.industry)
                        existing.billTitles.append(bill.title)
                        gainerCounts[key] = existing
                    } else {
                        gainerCounts[key] = CompanyRanking(
                            name: company,
                            count: 1,
                            industries: [entry.industry],
                            billTitles: [bill.title]
                        )
                    }
                }
            }

            for entry in analysis.losers {
                for company in entry.companies {
                    let key = company.lowercased()
                    if var existing = loserCounts[key] {
                        existing.count += 1
                        existing.industries.insert(entry.industry)
                        existing.billTitles.append(bill.title)
                        loserCounts[key] = existing
                    } else {
                        loserCounts[key] = CompanyRanking(
                            name: company,
                            count: 1,
                            industries: [entry.industry],
                            billTitles: [bill.title]
                        )
                    }
                }
            }
        }

        let sortedGainers = gainerCounts.values.sorted { $0.count > $1.count }
        let sortedLosers = loserCounts.values.sorted { $0.count > $1.count }
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
                    }
                    .padding()
                }
            }
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)

            // Rankings content
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

struct CompanyRanking: Identifiable {
    let name: String
    var count: Int
    var industries: Set<String>
    var billTitles: [String]

    var id: String { name.lowercased() }
}

struct RankingColumn: View {
    let title: String
    let icon: String
    let color: Color
    let rankings: [CompanyRanking]

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
                                        Spacer()
                                        Text("\(company.count) bill\(company.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(color.opacity(0.15))
                                            .foregroundStyle(color)
                                            .clipShape(Capsule())
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

                                    ForEach(company.billTitles.prefix(3), id: \.self) { title in
                                        Text(title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    if company.billTitles.count > 3 {
                                        Text("+\(company.billTitles.count - 3) more")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
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
