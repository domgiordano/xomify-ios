import Foundation

/// ViewModel for Release Radar screen
@Observable
final class ReleaseRadarViewModel {
    
    // MARK: - Properties
    
    var selectedView: ViewMode = .current
    var currentWeek: ReleaseRadarWeek?
    var pastWeeks: [ReleaseRadarWeek] = []
    var selectedWeek: ReleaseRadarWeek?
    
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    
    private let xomifyService = XomifyService.shared
    
    // MARK: - Enums
    
    enum ViewMode: String, CaseIterable {
        case current = "This Week"
        case history = "History"
    }
    
    // MARK: - Computed
    
    var displayedReleases: [Release] {
        switch selectedView {
        case .current:
            return currentWeek?.releases ?? []
        case .history:
            return selectedWeek?.releases ?? []
        }
    }
    
    var displayedWeek: ReleaseRadarWeek? {
        switch selectedView {
        case .current:
            return currentWeek
        case .history:
            return selectedWeek
        }
    }
    
    var stats: ReleaseStats? {
        displayedWeek?.stats
    }
    
    var albumCount: Int {
        displayedReleases.filter { $0.albumType?.lowercased() == "album" }.count
    }
    
    var singleCount: Int {
        displayedReleases.filter { $0.albumType?.lowercased() == "single" }.count
    }
    
    var featureCount: Int {
        displayedReleases.filter { $0.albumType?.lowercased() == "appears_on" }.count
    }
    
    // MARK: - Actions
    
    @MainActor
    func loadData() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        print("🚀 ReleaseRadar: Starting loadData...")
        
        do {
            // Load both current and history
            print("🚀 ReleaseRadar: Fetching live data...")
            let live = try await xomifyService.getReleaseRadarLive()
            print("✅ ReleaseRadar: Got live response - weekKey: \(live.weekKey), releases: \(live.week.releases.count)")
            
            print("🚀 ReleaseRadar: Fetching history...")
            let history = try await xomifyService.getReleaseRadarHistory(limit: 12)
            print("✅ ReleaseRadar: Got history - \(history.weeks.count) weeks")
            
            currentWeek = live.week
            pastWeeks = history.weeks.filter { $0.weekKey != live.weekKey }
            
            // Select first past week by default for history view
            if selectedWeek == nil, let first = pastWeeks.first {
                selectedWeek = first
            }
        } catch {
            print("❌ ReleaseRadar error: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func refresh() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        errorMessage = nil
        
        do {
            let response = try await xomifyService.refreshReleaseRadar()
            currentWeek = response.week
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRefreshing = false
    }
    
    @MainActor
    func selectWeek(_ week: ReleaseRadarWeek) {
        selectedWeek = week
    }
    
    @MainActor
    func onViewModeChange(_ mode: ViewMode) {
        selectedView = mode
    }
}

// MARK: - Week Display Helpers

extension ReleaseRadarWeek {
    /// Get Sunday-Saturday date range for display
    var dateRangeDisplay: String {
        guard let dates = weekKeyToDates() else { return weekKey }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let start = formatter.string(from: dates.start)
        let end = formatter.string(from: dates.end)
        
        return "\(start) - \(end)"
    }
    
    /// Parse weekKey to actual dates
    private func weekKeyToDates() -> (start: Date, end: Date)? {
        let parts = weekKey.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let week = Int(parts[1]) else {
            return nil
        }
        
        // ISO week to date conversion
        var components = DateComponents()
        components.weekOfYear = week
        components.yearForWeekOfYear = year
        components.weekday = 1 // Sunday
        
        guard let sunday = Calendar.current.date(from: components) else {
            return nil
        }
        
        let saturday = Calendar.current.date(byAdding: .day, value: 6, to: sunday) ?? sunday
        
        return (sunday, saturday)
    }
}
