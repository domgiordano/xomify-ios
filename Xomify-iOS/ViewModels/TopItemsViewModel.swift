import Foundation

/// ViewModel for Top Items screen
@Observable
final class TopItemsViewModel {
    
    // MARK: - Properties
    
    var selectedTab: TopItemsTab = .tracks
    var selectedTimeRange: TimeRange = .shortTerm
    
    var tracks: [SpotifyTrack] = []
    var artists: [SpotifyArtist] = []
    
    var isLoading = false
    var errorMessage: String?
    
    private let spotifyService = SpotifyService.shared
    
    // Cache for each time range
    private var tracksCache: [TimeRange: [SpotifyTrack]] = [:]
    private var artistsCache: [TimeRange: [SpotifyArtist]] = [:]
    
    // MARK: - Enums
    
    enum TopItemsTab: String, CaseIterable {
        case tracks = "Tracks"
        case artists = "Artists"
        
        var icon: String {
            switch self {
            case .tracks: return "music.note.list"
            case .artists: return "person.2.fill"
            }
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    func loadData() async {
        // Check cache first
        if selectedTab == .tracks, let cached = tracksCache[selectedTimeRange] {
            tracks = cached
            return
        }
        if selectedTab == .artists, let cached = artistsCache[selectedTimeRange] {
            artists = cached
            return
        }
        
        await fetchData()
    }
    
    @MainActor
    func fetchData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            switch selectedTab {
            case .tracks:
                let fetchedTracks = try await spotifyService.getTopTracks(
                    timeRange: selectedTimeRange,
                    limit: 50
                )
                tracks = fetchedTracks
                tracksCache[selectedTimeRange] = fetchedTracks
                
            case .artists:
                let fetchedArtists = try await spotifyService.getTopArtists(
                    timeRange: selectedTimeRange,
                    limit: 50
                )
                artists = fetchedArtists
                artistsCache[selectedTimeRange] = fetchedArtists
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func refresh() async {
        // Clear cache for current selection and refetch
        switch selectedTab {
        case .tracks:
            tracksCache[selectedTimeRange] = nil
        case .artists:
            artistsCache[selectedTimeRange] = nil
        }
        await fetchData()
    }
    
    @MainActor
    func onTabChange(_ tab: TopItemsTab) {
        selectedTab = tab
        Task {
            await loadData()
        }
    }
    
    @MainActor
    func onTimeRangeChange(_ range: TimeRange) {
        selectedTimeRange = range
        Task {
            await loadData()
        }
    }
}
