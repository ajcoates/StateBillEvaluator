import SwiftUI
import SwiftData

struct ImpactView: View {
    @Bindable var viewModel: LegislationViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let bill = viewModel.selectedBill {
                ImpactContentView(bill: bill, viewModel: viewModel, modelContext: modelContext)
            } else {
                ContentUnavailableView {
                    Label("Impact Analysis", systemImage: "chart.bar")
                } description: {
                    Text("Select a bill to see which industries and companies would be affected.")
                }
            }
        }
        .frame(minWidth: 280)
    }
}

struct ImpactContentView: View {
    let bill: Bill
    @Bindable var viewModel: LegislationViewModel
    let modelContext: ModelContext
    @State private var analysis: ImpactAnalysis?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Impact Analysis", systemImage: "chart.bar")
                    .font(.headline)
                Spacer()
                if analysis != nil {
                    Button {
                        Task { await refreshAnalysis() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh analysis")
                }
            }
            .padding()

            Divider()

            if isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Analyzing economic impact…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if let error {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await refreshAnalysis() }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let analysis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Winners
                        ImpactSectionView(
                            title: "Winners",
                            icon: "arrow.up.circle.fill",
                            color: .green,
                            entries: analysis.winners
                        )

                        Divider()

                        // Losers
                        ImpactSectionView(
                            title: "Losers",
                            icon: "arrow.down.circle.fill",
                            color: .red,
                            entries: analysis.losers
                        )
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "chart.bar")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Analyze which industries and companies would be affected by this bill.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Analyze Impact") {
                        Task { await refreshAnalysis() }
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .task(id: bill.billId) {
            loadCachedAnalysis()
        }
    }

    private func loadCachedAnalysis() {
        analysis = nil
        error = nil
        if let json = bill.impactAnalysisJSON,
           let data = json.data(using: .utf8),
           let cached = try? JSONDecoder().decode(ImpactAnalysis.self, from: data) {
            analysis = cached
        }
    }

    private func refreshAnalysis() async {
        isLoading = true
        error = nil

        let claude = ClaudeService()
        do {
            let result = try await claude.analyzeImpact(
                title: bill.title,
                description: bill.billDescription
            )
            analysis = result

            // Cache to SwiftData
            if let jsonData = try? JSONEncoder().encode(result),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                bill.impactAnalysisJSON = jsonString
                try? modelContext.save()
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

struct ImpactSectionView: View {
    let title: String
    let icon: String
    let color: Color
    let entries: [ImpactEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.industry)
                        .font(.body)
                        .fontWeight(.medium)

                    if !entry.companies.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(entry.companies, id: \.self) { company in
                                Text(company)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(color.opacity(0.1))
                                    .foregroundStyle(color)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }

                    Text(entry.reason)
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
