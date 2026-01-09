import Foundation

/// ViewModel for Release Radar screen
@Observable
@MainActor
final class ReleaseRadarViewModel {
    
    // MARK: - Properties
    
    var isLoading = false
    var errorMessage: String?
    
    // Current week (live from Spotify)
    var currentWeekKey: String?
    var currentWeekDisplay: String?
    var currentReleases: [Release] = []
    var currentStats: ReleaseStats?
    var currentStartDate: String?
    var currentEndDate: String?
    
    // History (from database)
    var historyWeeks: [ReleaseRadarWeek] = []
    var selectedHistoryWeek: ReleaseRadarWeek?
    
    // View state
    var showingHistory = false
    var isRefreshing = false
    
    // User email (set from profile)
    var userEmail: String?
    
    private let xomifyService = XomifyService.shared
    
    // MARK: - Computed
    
    var hasCurrentData: Bool {
        !currentReleases.isEmpty
    }
    
    var hasHistory: Bool {
        !historyWeeks.isEmpty
    }
    
    var displayReleases: [Release] {
        if showingHistory, let week = selectedHistoryWeek {
            return week.releases ?? []
        }
        return currentReleases
    }
    
    var displayStats: ReleaseStats? {
        if showingHistory, let week = selectedHistoryWeek {
            return ReleaseStats(from: week.stats)
        }
        return currentStats
    }
    
    var displayWeekKey: String? {
        if showingHistory {
            return selectedHistoryWeek?.weekKey
        }
        return currentWeekKey
    }
    
    var displayWeekName: String {
        if showingHistory, let week = selectedHistoryWeek {
            return week.displayName
        }
        return currentWeekDisplay ?? "This Week"
    }
    
    var displayDateRange: String? {
        if showingHistory, let week = selectedHistoryWeek {
            return week.dateRange
        }
        if let start = currentStartDate, let end = currentEndDate {
            return formatDateRange(start: start, end: end)
        }
        return nil
    }
    
    // MARK: - Actions
    
    func loadData() async {
        guard let email = userEmail else {
            errorMessage = "Please log in first"
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load current week live from Spotify
            let liveResponse = try await xomifyService.getReleaseRadarLive(email: email)
            currentWeekKey = liveResponse.weekKey
            currentWeekDisplay = liveResponse.weekDisplay
            currentStartDate = liveResponse.startDate
            currentEndDate = liveResponse.endDate
            currentReleases = liveResponse.releases ?? []
            currentStats = ReleaseStats(from: liveResponse)
            
            // Load history from database
            let historyResponse = try await xomifyService.getReleaseRadarHistory(email: email)
            historyWeeks = historyResponse.weeks ?? []
            
            print("✅ ReleaseRadar: Loaded \(currentReleases.count) current releases, \(historyWeeks.count) history weeks")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ ReleaseRadar: Error loading data - \(error)")
        }
        
        isLoading = false
    }
    
    func refresh() async {
        guard let email = userEmail else {
            errorMessage = "Please log in first"
            return
        }
        
        guard !isRefreshing else { return }
        
        isRefreshing = true
        errorMessage = nil
        
        do {
            // Refresh live data from Spotify
            let response = try await xomifyService.getReleaseRadarLive(email: email)
            currentWeekKey = response.weekKey
            currentWeekDisplay = response.weekDisplay
            currentStartDate = response.startDate
            currentEndDate = response.endDate
            currentReleases = response.releases ?? []
            currentStats = ReleaseStats(from: response)
            
            print("✅ ReleaseRadar: Refreshed with \(currentReleases.count) releases")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ ReleaseRadar: Error refreshing - \(error)")
        }
        
        isRefreshing = false
    }
    
    func selectHistoryWeek(_ week: ReleaseRadarWeek) {
        selectedHistoryWeek = week
        showingHistory = true
    }
    
    func showCurrentWeek() {
        showingHistory = false
        selectedHistoryWeek = nil
    }
    
    // MARK: - Helpers
    
    private func formatDateRange(start: String, end: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        
        guard let startDate = formatter.date(from: start),
              let endDate = formatter.date(from: end) else { return nil }
        
        return "\(displayFormatter.string(from: startDate)) - \(displayFormatter.string(from: endDate))"
    }
}
