import SwiftUI
import SwiftData

struct BillListView: View {
    @Bindable var viewModel: LegislationViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var allBills: [Bill]

    private var displayedBills: [Bill] {
        let bills: [Bill]
        if let categoryName = viewModel.selectedCategoryName {
            bills = allBills.filter { $0.categoryName == categoryName }
        } else {
            bills = allBills
        }
        return viewModel.filteredAndSortedBills(bills)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter bills…", text: $viewModel.filterText)
                    .textFieldStyle(.plain)

                Toggle("Passed", isOn: $viewModel.showPassedOnly)
                    .toggleStyle(.checkbox)
                    .fixedSize()

                Picker(selection: $viewModel.sortOrder) {
                    ForEach(LegislationViewModel.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
            .padding(8)
            .background(.bar)

            Divider()

            if displayedBills.isEmpty {
                ContentUnavailableView {
                    Label("No Bills", systemImage: "doc.text")
                } description: {
                    if allBills.isEmpty {
                        Text("Load sample data to preview, or sync with LegiScan.")
                    } else {
                        Text("No bills match the current filter.")
                    }
                } actions: {
                    if allBills.isEmpty {
                        Button("Load Sample Data") {
                            viewModel.loadSampleData(modelContext: modelContext)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List(selection: $viewModel.selectedBillId) {
                    ForEach(displayedBills, id: \.billId) { bill in
                        BillRowView(bill: bill)
                            .tag(bill.billId)
                    }
                }
                .listStyle(.inset)
                .onChange(of: viewModel.selectedBillId) { _, newId in
                    viewModel.selectedBill = allBills.first { $0.billId == newId }
                }
            }
        }
        .navigationTitle(viewModel.selectedCategoryName ?? "All Bills")
    }
}

struct BillRowView: View {
    let bill: Bill

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(bill.state)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stateColor.opacity(0.2))
                    .foregroundStyle(stateColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                LikelihoodBadge(likelihood: bill.passageLikelihood)

                if let categoryName = bill.categoryName {
                    Text(categoryName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let date = bill.lastActionDate {
                    Text(date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(bill.title)
                .font(.body)
                .lineLimit(2)

            if let lastAction = bill.lastAction {
                Text(lastAction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var stateColor: Color {
        let hash = bill.state.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .indigo, .mint, .pink, .cyan]
        return colors[abs(hash) % colors.count]
    }
}

struct LikelihoodBadge: View {
    let likelihood: Bill.PassageLikelihood

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .help("\(likelihood.rawValue) likelihood of passage")
    }

    private var color: Color {
        switch likelihood {
        case .low: return .red
        case .medium: return .yellow
        case .high: return .green
        case .passed: return .blue
        case .dead: return .gray
        }
    }
}
