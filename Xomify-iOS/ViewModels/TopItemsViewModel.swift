import Foundation

/// ViewModel for Top Items screen
@Observable
final class TopItemsViewModel {
    
    // MARK: - Properties
    
    var selectedTab: TopItemsTab = .tracks
    var selectedTimeRange: TimeRange = .shortTerm
    
    var tracks: [SpotifyTrack] = []
    var artists: [SpotifyArtist] = []
    var genres: [GenreCount] = []
    
    var isLoading = false
    var errorMessage: String?
    
    private let spotifyService = SpotifyService.shared
    
    // Cache for each time range
    private var tracksCache: [TimeRange: [SpotifyTrack]] = [:]
    private var artistsCache: [TimeRange: [SpotifyArtist]] = [:]
    private var genresCache: [TimeRange: [GenreCount]] = [:]
    
    // MARK: - Enums
    
    enum TopItemsTab: String, CaseIterable {
        case tracks = "Tracks"
        case artists = "Artists"
        case genres = "Genres"
        
        var icon: String {
            switch self {
            case .tracks: return "music.note.list"
            case .artists: return "person.2.fill"
            case .genres: return "guitars.fill"
            }
        }
    }
    
    struct GenreCount: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }
    
    // MARK: - Actions
    
    @MainActor
    func loadData() async {
        // Check cache first
        switch selectedTab {
        case .tracks:
            if let cached = tracksCache[selectedTimeRange] {
                tracks = cached
                return
            }
        case .artists:
            if let cached = artistsCache[selectedTimeRange] {
                artists = cached
                return
            }
        case .genres:
            if let cached = genresCache[selectedTimeRange] {
                genres = cached
                return
            }
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
                
                // Also compute genres from artists
                let genreCounts = computeGenres(from: fetchedArtists)
                genresCache[selectedTimeRange] = genreCounts
                
            case .genres:
                // Genres come from artists - fetch artists first if needed
                if let cachedArtists = artistsCache[selectedTimeRange] {
                    genres = computeGenres(from: cachedArtists)
                    genresCache[selectedTimeRange] = genres
                } else {
                    let fetchedArtists = try await spotifyService.getTopArtists(
                        timeRange: selectedTimeRange,
                        limit: 50
                    )
                    artistsCache[selectedTimeRange] = fetchedArtists
                    genres = computeGenres(from: fetchedArtists)
                    genresCache[selectedTimeRange] = genres
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func computeGenres(from artists: [SpotifyArtist]) -> [GenreCount] {
        var genreDict: [String: Int] = [:]
        
        for artist in artists {
            for genre in artist.genres ?? [] {
                genreDict[genre, default: 0] += 1
            }
        }
        
        return genreDict
            .map { GenreCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    @MainActor
    func refresh() async {
        // Clear cache for current selection and refetch
        switch selectedTab {
        case .tracks:
            tracksCache[selectedTimeRange] = nil
        case .artists:
            artistsCache[selectedTimeRange] = nil
            genresCache[selectedTimeRange] = nil
        case .genres:
            genresCache[selectedTimeRange] = nil
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
