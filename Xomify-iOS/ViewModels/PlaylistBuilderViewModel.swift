import SwiftUI

/// ViewModel for PlaylistBuilderView
/// Wraps PlaylistBuilderManager for view-specific logic
@Observable
@MainActor
final class PlaylistBuilderViewModel {
    
    // MARK: - Properties
    
    /// The shared manager that holds the tracks
    private let manager = PlaylistBuilderManager.shared
    private let spotifyService = SpotifyService.shared
    
    /// Playlist creation form fields
    var playlistName = "My Playlist"
    var playlistDescription = ""
    var isPublic = true
    
    /// Search
    var searchQuery = ""
    var searchResults: [SpotifyTrack] = []
    var isSearching = false
    var showingSearch = false
    
    // MARK: - Computed Properties (Forwarded from Manager)
    
    var tracks: [SpotifyTrack] { manager.tracks }
    var trackCount: Int { manager.trackCount }
    var isEmpty: Bool { manager.isEmpty }
    var totalDuration: String { manager.totalDuration }
    var isCreating: Bool { manager.isCreating }
    var successMessage: String? { manager.successMessage }
    var errorMessage: String? { manager.errorMessage }
    var createdPlaylistUrl: URL? { manager.createdPlaylistUrl }
    
    var isShowing: Bool {
        get { manager.isShowing }
        set { manager.isShowing = newValue }
    }
    
    // MARK: - Track Management (Forwarded to Manager)
    
    func addTrack(_ track: SpotifyTrack) {
        manager.addTrack(track)
    }
    
    func addTracks(_ tracks: [SpotifyTrack]) {
        manager.addTracks(tracks)
    }
    
    func removeTrack(_ track: SpotifyTrack) {
        manager.removeTrack(track)
    }
    
    func removeTrack(at index: Int) {
        manager.removeTrack(at: index)
    }
    
    func moveTrack(from source: IndexSet, to destination: Int) {
        manager.moveTrack(from: source, to: destination)
    }
    
    func contains(_ track: SpotifyTrack) -> Bool {
        manager.contains(track)
    }
    
    func clear() {
        manager.clear()
    }
    
    func shuffleTracks() {
        var shuffled = manager.tracks
        shuffled.shuffle()
        manager.clear()
        manager.addTracks(shuffled)
    }
    
    // MARK: - Search
    
    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        do {
            searchResults = try await spotifyService.searchTracks(query: query, limit: 20)
            print("✅ PlaylistBuilder: Found \(searchResults.count) tracks for '\(query)'")
        } catch {
            print("❌ PlaylistBuilder: Search error - \(error)")
            searchResults = []
        }
        
        isSearching = false
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }
    
    // MARK: - Playlist Creation
    
    func createPlaylist() async {
        await manager.createPlaylist(
            name: playlistName.isEmpty ? "My Playlist" : playlistName,
            description: playlistDescription,
            isPublic: isPublic
        )
        
        // Reset form on success
        if manager.successMessage != nil {
            resetForm()
        }
    }
    
    func resetForm() {
        playlistName = "My Playlist"
        playlistDescription = ""
        isPublic = true
    }
    
    func clearSuccess() {
        manager.successMessage = nil
        manager.createdPlaylistUrl = nil
    }
    
    // MARK: - Helpers
    
    /// Get album art URLs for playlist preview grid
    var previewImageUrls: [URL] {
        Array(tracks.compactMap { $0.imageUrl }.prefix(4))
    }
}
