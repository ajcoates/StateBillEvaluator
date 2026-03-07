import Foundation
import SwiftData

@MainActor
final class SyncService {
    private let legiScan = LegiScanService()
    private let claude = ClaudeService()

    struct SyncProgress: Sendable {
        var totalBills: Int = 0
        var fetchedBills: Int = 0
        var categorizedBills: Int = 0
        var phase: Phase = .idle

        enum Phase: String, Sendable {
            case idle = "Idle"
            case fetching = "Fetching bills…"
            case categorizing = "Categorizing bills…"
            case complete = "Sync complete"
            case error = "Error"
        }
    }

    func syncBills(
        query: String,
        states: [String],
        modelContext: ModelContext,
        progressHandler: (SyncProgress) -> Void
    ) async throws {
        var progress = SyncProgress()
        progress.phase = .fetching
        progressHandler(progress)

        // Fetch bills from LegiScan
        var allBills: [LegiScanBillSummary] = []

        if states.isEmpty {
            let bills = try await legiScan.searchBills(query: query)
            allBills.append(contentsOf: bills)
        } else {
            for state in states {
                let bills = try await legiScan.searchBills(query: query, state: state)
                allBills.append(contentsOf: bills)
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        progress.totalBills = allBills.count
        progressHandler(progress)

        // Upsert bills into SwiftData
        var uncategorizedBills: [Bill] = []

        for summary in allBills {
            let billId = summary.bill_id

            let descriptor = FetchDescriptor<Bill>(
                predicate: #Predicate { $0.billId == billId }
            )
            let existing = try modelContext.fetch(descriptor)

            if let existingBill = existing.first {
                existingBill.title = summary.title ?? existingBill.title
                existingBill.lastAction = summary.last_action
                existingBill.lastActionDate = summary.last_action_date
                existingBill.lastUpdated = .now
                if let url = summary.url, !url.isEmpty {
                    existingBill.url = url
                }
                if existingBill.categoryName == nil {
                    uncategorizedBills.append(existingBill)
                }
            } else {
                let bill = Bill(
                    billId: summary.bill_id,
                    title: summary.title ?? "Untitled",
                    billDescription: summary.title ?? "",
                    state: summary.state ?? "US",
                    status: summary.last_action ?? "Unknown",
                    session: "",
                    url: summary.url ?? "",
                    lastAction: summary.last_action,
                    lastActionDate: summary.last_action_date
                )
                modelContext.insert(bill)
                uncategorizedBills.append(bill)
            }

            progress.fetchedBills += 1
            progressHandler(progress)
        }

        try modelContext.save()

        // Categorize uncategorized bills via Claude
        progress.phase = .categorizing
        progressHandler(progress)

        // Ensure categories exist
        for categoryName in BillCategory.predefinedCategories {
            let descriptor = FetchDescriptor<BillCategory>(
                predicate: #Predicate { $0.name == categoryName }
            )
            let existing = try modelContext.fetch(descriptor)
            if existing.isEmpty {
                modelContext.insert(BillCategory(name: categoryName))
            }
        }
        try modelContext.save()

        for bill in uncategorizedBills {
            do {
                let categoryName = try await claude.categorizeBill(
                    title: bill.title,
                    description: bill.billDescription
                )
                bill.categoryName = categoryName

                // Link to category
                let descriptor = FetchDescriptor<BillCategory>(
                    predicate: #Predicate { $0.name == categoryName }
                )
                if let category = try modelContext.fetch(descriptor).first {
                    bill.category = category
                }
            } catch {
                print("Failed to categorize bill \(bill.billId): \(error)")
            }

            progress.categorizedBills += 1
            progressHandler(progress)
        }

        try modelContext.save()

        progress.phase = .complete
        progressHandler(progress)
    }

    func fetchBillDetail(billId: Int, modelContext: ModelContext) async throws {
        let detail = try await legiScan.getBill(id: billId)

        let descriptor = FetchDescriptor<Bill>(
            predicate: #Predicate { $0.billId == billId }
        )

        guard let bill = try modelContext.fetch(descriptor).first else { return }

        bill.billDescription = detail.description ?? bill.billDescription
        bill.status = detail.status_desc ?? bill.status
        bill.url = detail.url
        bill.session = detail.session?.session_name ?? ""

        if let sponsors = detail.sponsors {
            bill.sponsors = sponsors.map { sponsor in
                let party = sponsor.party.map { " (\($0))" } ?? ""
                return "\(sponsor.name)\(party)"
            }.joined(separator: ", ")
        }

        try modelContext.save()
    }
}
