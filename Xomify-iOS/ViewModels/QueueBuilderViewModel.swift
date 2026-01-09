import Foundation

/// Track in the queue
struct QueueTrack: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum?
    let durationMs: Int
    let externalUrls: [String: String]?
    
    var artistNames: String {
        artists.map { $0.name }.joined(separator: ", ")
    }
    
    var albumImageUrl: URL? {
        album?.imageUrl
    }
    
    var spotifyUrl: URL? {
        if let urlString = externalUrls?["spotify"] {
            return URL(string: urlString)
        }
        return URL(string: "https://open.spotify.com/track/\(id)")
    }
    
    static func == (lhs: QueueTrack, rhs: QueueTrack) -> Bool {
        lhs.id == rhs.id
    }
}

/// ViewModel for Queue Builder screen
@Observable
@MainActor
final class QueueBuilderViewModel {
    
    // MARK: - Properties
    
    // Search
    var searchQuery = ""
    var searchResults: [SpotifyTrack] = []
    var isSearching = false
    
    // Queue
    var queue: [QueueTrack] = []
    
    // Playlist creation
    var playlistName = ""
    var playlistDescription = ""
    var isPublic = false
    var isSaving = false
    var showSaveModal = false
    var savedPlaylistUrl: URL?
    
    var errorMessage: String?
    
    private let spotifyService = SpotifyService.shared
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Computed
    
    var totalDurationMs: Int {
        queue.reduce(0) { $0 + $1.durationMs }
    }
    
    var totalDurationFormatted: String {
        let totalSeconds = totalDurationMs / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }
    
    var uniqueArtistCount: Int {
        var artistIds = Set<String>()
        for track in queue {
            for artist in track.artists {
                if let id = artist.id {
                    artistIds.insert(id)
                }
            }
        }
        return artistIds.count
    }
    
    // MARK: - Search
    
    func search() {
        // Cancel previous search
        searchTask?.cancel()
        
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            isSearching = true
            
            do {
                let results = try await spotifyService.searchTracks(query: query, limit: 20)
                
                guard !Task.isCancelled else { return }
                
                searchResults = results
                print("🔍 Queue: Found \(results.count) tracks for '\(query)'")
            } catch {
                guard !Task.isCancelled else { return }
                print("❌ Queue: Search error - \(error)")
                errorMessage = "Search failed"
            }
            
            isSearching = false
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchTask?.cancel()
    }
    
    // MARK: - Queue Management
    
    func addToQueue(_ track: SpotifyTrack) {
        // Don't add duplicates
        guard !isInQueue(track.id) else { return }
        
        let queueTrack = QueueTrack(
            id: track.id,
            name: track.name,
            artists: track.artists,
            album: track.album,
            durationMs: track.durationMs,
            externalUrls: track.externalUrls
        )
        
        queue.append(queueTrack)
        print("➕ Queue: Added '\(track.name)' - total: \(queue.count)")
    }
    
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        let removed = queue.remove(at: index)
        print("➖ Queue: Removed '\(removed.name)' - total: \(queue.count)")
    }
    
    func removeFromQueue(id: String) {
        if let index = queue.firstIndex(where: { $0.id == id }) {
            removeFromQueue(at: index)
        }
    }
    
    func moveTrack(from source: Int, to destination: Int) {
        guard source >= 0 && source < queue.count,
              destination >= 0 && destination < queue.count,
              source != destination else { return }
        
        let track = queue.remove(at: source)
        queue.insert(track, at: destination)
    }
    
    func clearQueue() {
        queue.removeAll()
        print("🗑️ Queue: Cleared all tracks")
    }
    
    func isInQueue(_ trackId: String) -> Bool {
        queue.contains { $0.id == trackId }
    }
    
    // MARK: - Playlist Creation
    
    func openSaveModal() {
        guard !queue.isEmpty else {
            errorMessage = "Add tracks to your queue first"
            return
        }
        playlistName = ""
        playlistDescription = ""
        isPublic = false
        showSaveModal = true
    }
    
    func closeSaveModal() {
        showSaveModal = false
    }
    
    func saveAsPlaylist() async {
        let name = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Please enter a playlist name"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            // Get current user
            let user = try await spotifyService.getCurrentUser()
            
            guard let userId = user.id else {
                throw NSError(domain: "QueueBuilder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not get user ID"])
            }
            
            // Create playlist
            let description = playlistDescription.isEmpty ? "Created with Xomify Queue Builder" : playlistDescription
            let playlist = try await spotifyService.createPlaylist(
                userId: userId,
                name: name,
                description: description,
                isPublic: isPublic
            )
            
            // Add tracks to playlist
            let trackUris = queue.map { "spotify:track:\($0.id)" }
            try await spotifyService.addTracksToPlaylist(playlistId: playlist.id, trackUris: trackUris)
            
            // Save URL for opening
            if let urlString = playlist.externalUrls?["spotify"] {
                savedPlaylistUrl = URL(string: urlString)
            }
            
            print("✅ Queue: Created playlist '\(name)' with \(queue.count) tracks")
            
            // Clear queue and close modal
            clearQueue()
            closeSaveModal()
            
        } catch {
            print("❌ Queue: Failed to create playlist - \(error)")
            errorMessage = "Failed to create playlist"
        }
        
        isSaving = false
    }
    
    // MARK: - Utilities
    
    func formatDuration(_ ms: Int) -> String {
        let minutes = ms / 60000
        let seconds = (ms % 60000) / 1000
        return String(format: "%d:%02d", minutes, seconds)
    }
}
