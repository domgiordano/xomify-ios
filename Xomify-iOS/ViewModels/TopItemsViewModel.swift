import Foundation

/// ViewModel for Top Items screen
@Observable
@MainActor
final class TopItemsViewModel {
    
    // MARK: - Properties
    
    var isLoading = false
    var errorMessage: String?
    
    // Tracks by term
    var shortTermTracks: [SpotifyTrack] = []
    var mediumTermTracks: [SpotifyTrack] = []
    var longTermTracks: [SpotifyTrack] = []
    
    // Artists by term
    var shortTermArtists: [SpotifyArtist] = []
    var mediumTermArtists: [SpotifyArtist] = []
    var longTermArtists: [SpotifyArtist] = []
    
    // Genres by term (computed from artists)
    var shortTermGenres: [(name: String, count: Int)] = []
    var mediumTermGenres: [(name: String, count: Int)] = []
    var longTermGenres: [(name: String, count: Int)] = []
    
    private let spotifyService = SpotifyService.shared
    
    // MARK: - Actions
    
    func loadData() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load all tracks concurrently
            async let shortTracks = spotifyService.getTopTracks(timeRange: .shortTerm, limit: 50)
            async let mediumTracks = spotifyService.getTopTracks(timeRange: .mediumTerm, limit: 50)
            async let longTracks = spotifyService.getTopTracks(timeRange: .longTerm, limit: 50)
            
            // Load all artists concurrently
            async let shortArtists = spotifyService.getTopArtists(timeRange: .shortTerm, limit: 50)
            async let mediumArtists = spotifyService.getTopArtists(timeRange: .mediumTerm, limit: 50)
            async let longArtists = spotifyService.getTopArtists(timeRange: .longTerm, limit: 50)
            
            // Await all
            shortTermTracks = try await shortTracks
            mediumTermTracks = try await mediumTracks
            longTermTracks = try await longTracks
            
            shortTermArtists = try await shortArtists
            mediumTermArtists = try await mediumArtists
            longTermArtists = try await longArtists
            
            // Compute genres from artists
            shortTermGenres = computeGenres(from: shortTermArtists)
            mediumTermGenres = computeGenres(from: mediumTermArtists)
            longTermGenres = computeGenres(from: longTermArtists)
            
            print("✅ TopItems: Loaded \(shortTermTracks.count) short-term tracks, \(mediumTermTracks.count) medium-term, \(longTermTracks.count) long-term")
            print("✅ TopItems: Loaded \(shortTermArtists.count) short-term artists, \(mediumTermArtists.count) medium-term, \(longTermArtists.count) long-term")
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ TopItems: Error loading data - \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private func computeGenres(from artists: [SpotifyArtist]) -> [(name: String, count: Int)] {
        var genreCounts: [String: Int] = [:]
        
        for artist in artists {
            for genre in artist.genres ?? [] {
                genreCounts[genre, default: 0] += 1
            }
        }
        
        return genreCounts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}
