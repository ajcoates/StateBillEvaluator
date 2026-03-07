import SwiftUI

struct CompaniesView: View {
    @Bindable var viewModel: LegislationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Companies Affected", systemImage: "building.2")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            if let bill = viewModel.selectedBill,
               let json = bill.impactAnalysisJSON,
               let data = json.data(using: .utf8),
               let analysis = try? JSONDecoder().decode(ImpactAnalysis.self, from: data) {

                let benefiting = extractCompanies(from: analysis.winners)
                let harmed = extractCompanies(from: analysis.losers)

                if benefiting.isEmpty && harmed.isEmpty {
                    noCompaniesView(message: "No specific companies identified for this bill.")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !benefiting.isEmpty {
                                CompanySection(
                                    title: "Benefiting",
                                    icon: "arrow.up.right",
                                    color: .green,
                                    companies: benefiting
                                )
                            }

                            if !benefiting.isEmpty && !harmed.isEmpty {
                                Divider()
                            }

                            if !harmed.isEmpty {
                                CompanySection(
                                    title: "At Risk",
                                    icon: "arrow.down.right",
                                    color: .red,
                                    companies: harmed
                                )
                            }
                        }
                        .padding()
                    }
                }
            } else if viewModel.selectedBill != nil {
                noCompaniesView(message: "Run the Impact Analysis first to see affected companies.")
            } else {
                noCompaniesView(message: "Select a bill to see affected companies.")
            }
        }
        .frame(minWidth: 220)
    }

    private func noCompaniesView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "building.2")
                .font(.title)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func extractCompanies(from entries: [ImpactEntry]) -> [CompanyInfo] {
        var result: [CompanyInfo] = []
        for entry in entries {
            for company in entry.companies {
                result.append(CompanyInfo(
                    name: company,
                    industry: entry.industry,
                    reason: entry.reason
                ))
            }
        }
        return result
    }
}

struct CompanyInfo: Identifiable {
    let name: String
    let industry: String
    let reason: String
    var id: String { "\(name)-\(industry)" }
}

struct CompanySection: View {
    let title: String
    let icon: String
    let color: Color
    let companies: [CompanyInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            ForEach(companies) { company in
                VStack(alignment: .leading, spacing: 4) {
                    Text(company.name)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(company.industry)
                        .font(.caption)
                        .foregroundStyle(color)

                    Text(company.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
