import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LegislationViewModel()

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
                    viewModel.loadSampleData(modelContext: modelContext)
                } label: {
                    Label("Load Sample Data", systemImage: "doc.badge.plus")
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
