import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class LegislationViewModel {
    var selectedCategoryName: String? = nil
    var selectedBillId: Int? = nil
    var selectedBill: Bill?
    var searchQuery: String = ""
    var syncSearchQuery: String = "healthcare"
    var syncStates: String = ""
    var isSyncing: Bool = false
    var syncProgress: SyncService.SyncProgress = .init()
    var errorMessage: String?
    var sortOrder: SortOrder = .byState
    var filterText: String = ""
    var showPassedOnly: Bool = false
    var showingSyncSheet: Bool = false

    private let syncService = SyncService()

    enum SortOrder: String, CaseIterable, Sendable {
        case byState = "State"
        case byDate = "Date"
        case byTitle = "Title"
        case byLikelihood = "Likelihood"
    }

    func startSync(modelContext: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        errorMessage = nil

        let states = syncStates
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }

        do {
            try await syncService.syncBills(
                query: syncSearchQuery,
                states: states,
                modelContext: modelContext,
                progressHandler: { [weak self] progress in
                    self?.syncProgress = progress
                }
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isSyncing = false
    }

    func fetchBillDetail(bill: Bill, modelContext: ModelContext) async {
        do {
            try await syncService.fetchBillDetail(billId: bill.billId, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSampleData(modelContext: ModelContext) {
        // Create categories
        var categoryMap: [String: BillCategory] = [:]
        for name in BillCategory.predefinedCategories {
            let cat = BillCategory(name: name)
            modelContext.insert(cat)
            categoryMap[name] = cat
        }

        let sampleBills: [(Int, String, String, String, String, String, String, String, String?, String?)] = [
            (100001, "SB 1234 - Universal Healthcare Coverage Act", "Establishes a single-payer healthcare system providing comprehensive coverage to all state residents, funded through a payroll tax and general fund appropriations.", "CA", "Referred to Committee on Health", "2025-2026 Regular Session", "Healthcare", "https://leginfo.legislature.ca.gov", "2026-01-15", "Referred to Senate Health Committee"),
            (100002, "HB 567 - School Choice Expansion Act", "Expands school voucher programs to allow parents to use public education funds at private and charter schools of their choice.", "TX", "Passed House", "89th Legislature", "Education", "https://capitol.texas.gov", "2026-02-01", "Passed House 85-60"),
            (100003, "AB 890 - Criminal Justice Reform Act", "Reduces mandatory minimum sentences for non-violent drug offenses and establishes rehabilitative programs for incarcerated individuals.", "NY", "In Committee", "2025-2026 Regular Session", "Criminal Justice", "https://nyassembly.gov", "2026-01-20", "Referred to Assembly Judiciary Committee"),
            (100004, "SB 234 - Property Tax Relief Act", "Provides property tax exemptions for seniors and disabled veterans, caps annual property tax increases at 3%.", "FL", "Passed Senate", "2026 Regular Session", "Taxation", "https://flsenate.gov", "2026-02-10", "Passed Senate 30-8"),
            (100005, "HB 1011 - Clean Energy Transition Act", "Mandates 100% renewable energy for electricity generation by 2040, establishes green energy tax credits for businesses.", "WA", "In Committee", "2025-2026 Regular Session", "Energy", "https://leg.wa.gov", "2026-01-25", "Referred to House Environment Committee"),
            (100006, "SB 445 - Voter ID Requirements Act", "Requires government-issued photo identification to vote in all state and local elections, provides free ID cards.", "GA", "Passed Senate", "2025-2026 Regular Session", "Elections", "https://legis.ga.gov", "2026-02-05", "Passed Senate 33-22"),
            (100007, "AB 2100 - Affordable Housing Development Act", "Creates a $2 billion fund for affordable housing construction, streamlines zoning for multi-family developments.", "CA", "In Committee", "2025-2026 Regular Session", "Housing", "https://leginfo.legislature.ca.gov", "2026-01-30", "Referred to Assembly Housing Committee"),
            (100008, "HB 789 - Data Privacy Protection Act", "Establishes comprehensive consumer data privacy rights including right to delete, opt-out of data sales, and data portability.", "IL", "Passed House", "103rd General Assembly", "Technology & Privacy", "https://ilga.gov", "2026-02-12", "Passed House 72-41"),
            (100009, "SB 901 - Minimum Wage Increase Act", "Raises the state minimum wage to $18/hour by 2028, with annual cost-of-living adjustments thereafter.", "OR", "In Committee", "2025-2026 Regular Session", "Labor", "https://oregonlegislature.gov", "2026-01-18", "Referred to Senate Labor Committee"),
            (100010, "HB 333 - Agricultural Water Rights Act", "Reforms water allocation for agricultural use, establishes conservation incentives for farmers.", "CO", "In Committee", "75th General Assembly", "Agriculture", "https://leg.colorado.gov", "2026-02-08", "Referred to House Agriculture Committee"),
            (100011, "SB 678 - Concealed Carry Permit Reform", "Eliminates permit requirements for concealed carry of handguns for residents over 21 with no felony convictions.", "OH", "Passed Senate", "135th General Assembly", "Gun Policy", "https://legislature.ohio.gov", "2026-01-28", "Passed Senate 22-11"),
            (100012, "AB 1500 - Immigrant Worker Protection Act", "Provides workplace protections for undocumented workers including wage theft prevention and safe working conditions.", "NJ", "In Committee", "2026-2027 Session", "Immigration", "https://njleg.state.nj.us", "2026-02-14", "Referred to Assembly Labor Committee"),
            (100013, "HB 2200 - State Budget Transparency Act", "Requires all state agencies to publish detailed spending reports quarterly, creates an independent budget oversight board.", "PA", "In Committee", "2025-2026 Regular Session", "Budget & Appropriations", "https://legis.state.pa.us", "2026-02-03", "Referred to House Appropriations Committee"),
            (100014, "SB 112 - Electric Vehicle Infrastructure Act", "Funds installation of 10,000 EV charging stations statewide, provides tax credits for EV purchases.", "MI", "Passed Senate", "103rd Legislature", "Transportation", "https://legislature.mi.gov", "2026-01-22", "Passed Senate 24-14"),
            (100015, "HB 456 - Wetlands and Waterways Protection Act", "Strengthens protections for wetlands and waterways, increases penalties for illegal dumping and pollution.", "MN", "In Committee", "93rd Legislature", "Environment", "https://leg.mn.gov", "2026-02-06", "Referred to House Environment Committee"),
            (100016, "AB 3000 - Telehealth Expansion Act", "Permanently authorizes telehealth services, requires insurance parity for virtual and in-person visits.", "CA", "Passed Assembly", "2025-2026 Regular Session", "Healthcare", "https://leginfo.legislature.ca.gov", "2026-02-15", "Passed Assembly 55-18"),
            (100017, "SB 890 - Charter School Accountability Act", "Requires charter schools to meet same transparency and performance standards as public schools.", "AZ", "In Committee", "56th Legislature", "Education", "https://azleg.gov", "2026-01-12", "Referred to Senate Education Committee"),
            (100018, "HB 1750 - Police Body Camera Act", "Mandates body cameras for all law enforcement officers, establishes footage retention and public access policies.", "VA", "Passed House", "2026 Session", "Criminal Justice", "https://lis.virginia.gov", "2026-02-11", "Passed House 60-38"),
            (100019, "SB 555 - Corporate Tax Reform Act", "Closes corporate tax loopholes, establishes a minimum effective corporate tax rate of 7.5%.", "MA", "In Committee", "193rd General Court", "Taxation", "https://malegislature.gov", "2026-01-29", "Referred to Senate Revenue Committee"),
            (100020, "HB 999 - Paid Family Leave Act", "Establishes 12 weeks of paid family and medical leave funded through employee and employer payroll contributions.", "NC", "In Committee", "2025-2026 Session", "Labor", "https://ncleg.gov", "2026-02-09", "Referred to House Commerce Committee"),
        ]

        for (id, title, desc, state, status, session, category, url, date, action) in sampleBills {
            let bill = Bill(
                billId: id,
                title: title,
                billDescription: desc,
                state: state,
                status: status,
                session: session,
                url: url,
                categoryName: category,
                lastAction: action,
                lastActionDate: date
            )
            if let cat = categoryMap[category] {
                bill.category = cat
            }
            modelContext.insert(bill)
        }

        try? modelContext.save()
    }

    func filteredAndSortedBills(_ bills: [Bill]) -> [Bill] {
        var result = bills

        if showPassedOnly {
            result = result.filter { $0.passageLikelihood == .passed || $0.passageLikelihood == .high }
        }

        if !filterText.isEmpty {
            result = result.filter { bill in
                bill.title.localizedCaseInsensitiveContains(filterText) ||
                bill.state.localizedCaseInsensitiveContains(filterText) ||
                bill.billDescription.localizedCaseInsensitiveContains(filterText)
            }
        }

        switch sortOrder {
        case .byState:
            result.sort { $0.state < $1.state }
        case .byDate:
            result.sort { ($0.lastActionDate ?? "") > ($1.lastActionDate ?? "") }
        case .byTitle:
            result.sort { $0.title < $1.title }
        case .byLikelihood:
            let order: [Bill.PassageLikelihood] = [.passed, .high, .medium, .low, .dead]
            result.sort { (order.firstIndex(of: $0.passageLikelihood) ?? 4) < (order.firstIndex(of: $1.passageLikelihood) ?? 4) }
        }

        return result
    }
}
