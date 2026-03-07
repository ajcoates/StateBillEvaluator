import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LegislationViewModel()
    @Query private var allBills: [Bill]
    @State private var showingExportError = false

    var body: some View {
        HStack(spacing: 0) {
            NavigationSplitView {
                SidebarView(viewModel: viewModel)
            } content: {
                BillListView(viewModel: viewModel)
            } detail: {
                BillDetailView(viewModel: viewModel)
            }
            .navigationSplitViewStyle(.balanced)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            ImpactView(viewModel: viewModel)
                .frame(width: 320)

            Divider()

            CompaniesView(viewModel: viewModel)
                .frame(width: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $viewModel.showingSyncSheet) {
            SyncSheetView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingSyncSheet = true
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.isSyncing)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    exportBills()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(allBills.isEmpty)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.loadSampleData(modelContext: modelContext)
                } label: {
                    Label("Load Sample Data", systemImage: "doc.badge.plus")
                }
            }
        }
    }
    private func exportBills() {
        let csv = viewModel.exportCSV(bills: allBills)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "bills_export.csv"
        panel.title = "Export Bills"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Export error: \(error)")
                }
            }
        }
    }
}

struct SyncSheetView: View {
    @Bindable var viewModel: LegislationViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Sync Legislation")
                .font(.headline)

            Form {
                TextField("Search Query", text: $viewModel.syncSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g. healthcare, education, gun control")

                TextField("States (comma-separated, leave empty for all)", text: $viewModel.syncStates)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g. CA, NY, TX")
            }
            .formStyle(.grouped)

            if viewModel.isSyncing {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(viewModel.syncProgress.phase.rawValue)
                        .font(.caption)
                    if viewModel.syncProgress.totalBills > 0 {
                        Text("Fetched: \(viewModel.syncProgress.fetchedBills)/\(viewModel.syncProgress.totalBills) | Categorized: \(viewModel.syncProgress.categorizedBills)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Start Sync") {
                    Task {
                        await viewModel.startSync(modelContext: modelContext)
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isSyncing || viewModel.syncSearchQuery.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
