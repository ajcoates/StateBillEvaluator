import SwiftUI
import SwiftData

struct BillDetailView: View {
    @Bindable var viewModel: LegislationViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var isLoadingDetail = false

    var body: some View {
        Group {
            if let bill = viewModel.selectedBill {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(bill.state)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                if let categoryName = bill.categoryName {
                                    Text(categoryName)
                                        .font(.subheadline)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.15))
                                        .foregroundStyle(.green)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                HStack(spacing: 4) {
                                    LikelihoodBadge(likelihood: bill.passageLikelihood)
                                    Text(bill.passageLikelihood.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                            }

                            Text(bill.title)
                                .font(.title2)
                                .fontWeight(.semibold)

                            if !bill.url.isEmpty, let url = URL(string: bill.url) {
                                Link(destination: url) {
                                    HStack {
                                        Image(systemName: "safari")
                                        Text("View on State Legislature Website")
                                        Text("(\(bill.url))")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .font(.subheadline)
                                    .padding(10)
                                    .background(.blue.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                        Divider()

                        // Details
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], alignment: .leading, spacing: 12) {
                            DetailField(label: "Status", value: bill.status)
                            DetailField(label: "Session", value: bill.session.isEmpty ? "—" : bill.session)
                            DetailField(label: "Last Action Date", value: bill.lastActionDate ?? "—")
                            DetailField(label: "Bill ID", value: "\(bill.billId)")
                        }

                        if let sponsors = bill.sponsors, !sponsors.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sponsors")
                                    .font(.headline)
                                Text(sponsors)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let lastAction = bill.lastAction {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last Action")
                                    .font(.headline)
                                Text(lastAction)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !bill.billDescription.isEmpty && bill.billDescription != bill.title {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description")
                                    .font(.headline)
                                Text(bill.billDescription)
                                    .font(.body)
                            }
                        }

                        if let billText = bill.billText, !billText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bill Text")
                                    .font(.headline)
                                Text(billText)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding()
                }
                .task(id: bill.billId) {
                    if bill.session.isEmpty {
                        isLoadingDetail = true
                        await viewModel.fetchBillDetail(bill: bill, modelContext: modelContext)
                        isLoadingDetail = false
                    }
                }
                .overlay {
                    if isLoadingDetail {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ProgressView("Loading details…")
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Select a Bill", systemImage: "doc.text")
                } description: {
                    Text("Choose a bill from the list to view its details.")
                }
            }
        }
    }
}

struct DetailField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
}
