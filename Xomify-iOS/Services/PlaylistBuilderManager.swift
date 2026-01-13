import SwiftUI

/// Global manager for building playlists from songs added throughout the app
@Observable
@MainActor
final class PlaylistBuilderManager {
    
    static let shared = PlaylistBuilderManager()
    
    // MARK: - Properties
    
    /// Tracks added to the playlist builder
    private(set) var tracks: [SpotifyTrack] = []
    
    /// Whether the playlist builder sheet is showing
    var isShowing = false
    
    /// Whether we're currently creating the playlist
    var isCreating = false
    
    /// Success message after playlist creation
    var successMessage: String?
    
    /// Error message if creation fails
    var errorMessage: String?
    
    /// Created playlist URL for opening in Spotify
    var createdPlaylistUrl: URL?
    
    private init() {}
    
    // MARK: - Computed
    
    var trackCount: Int { tracks.count }
    var isEmpty: Bool { tracks.isEmpty }
    var hasTrack: Bool { !tracks.isEmpty }
    
    /// Total duration of all tracks
    var totalDuration: String {
        let totalMs = tracks.compactMap { $0.durationMs }.reduce(0, +)
        let minutes = totalMs / 60000
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }
    
    // MARK: - Actions
    
    /// Add a track to the playlist builder
    func addTrack(_ track: SpotifyTrack) {
        // Avoid duplicates
        guard !tracks.contains(where: { $0.id == track.id }) else {
            print("⚠️ PlaylistBuilder: Track already in list - \(track.name)")
            return
        }
        
        tracks.append(track)
        print("✅ PlaylistBuilder: Added '\(track.name)' - \(tracks.count) tracks total")
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Add multiple tracks at once
    func addTracks(_ newTracks: [SpotifyTrack]) {
        for track in newTracks {
            if !tracks.contains(where: { $0.id == track.id }) {
                tracks.append(track)
            }
        }
        print("✅ PlaylistBuilder: Added \(newTracks.count) tracks - \(tracks.count) total")
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Remove a track from the playlist builder
    func removeTrack(_ track: SpotifyTrack) {
        tracks.removeAll { $0.id == track.id }
        print("✅ PlaylistBuilder: Removed '\(track.name)' - \(tracks.count) tracks remaining")
    }
    
    /// Remove track at index
    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        let track = tracks.remove(at: index)
        print("✅ PlaylistBuilder: Removed '\(track.name)' - \(tracks.count) tracks remaining")
    }
    
    /// Move track within the list
    func moveTrack(from source: IndexSet, to destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
    }
    
    /// Check if a track is already in the builder
    func contains(_ track: SpotifyTrack) -> Bool {
        tracks.contains { $0.id == track.id }
    }
    
    /// Clear all tracks
    func clear() {
        tracks.removeAll()
        successMessage = nil
        errorMessage = nil
        createdPlaylistUrl = nil
        print("✅ PlaylistBuilder: Cleared all tracks")
    }
    
    /// Show the playlist builder sheet
    func show() {
        isShowing = true
    }
    
    /// Create the playlist on Spotify
    func createPlaylist(name: String, description: String = "", isPublic: Bool = true, coverImageBase64: String? = nil) async {
        guard !tracks.isEmpty else {
            errorMessage = "Add some tracks first!"
            return
        }
        
        isCreating = true
        errorMessage = nil
        successMessage = nil
        
        let spotifyService = SpotifyService.shared
        
        do {
            // 1. Get current user ID
            let user = try await spotifyService.getCurrentUser()
            guard let userId = user.id else {
                throw NSError(domain: "PlaylistBuilder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not get user ID"])
            }
            
            // 2. Create the playlist
            let playlist = try await spotifyService.createPlaylist(
                userId: userId,
                name: name,
                description: description.isEmpty ? XomifyConstants.defaultPlaylistDescription : description,
                isPublic: isPublic
            )
            
            // 3. Add tracks to the playlist
            let trackUris = tracks.compactMap { $0.uri }
            if !trackUris.isEmpty {
                try await spotifyService.addTracksToPlaylist(playlistId: playlist.id, trackUris: trackUris)
            }
            
            // 4. Upload cover image - use provided image or default Xomify cover
            let imageToUpload = coverImageBase64 ?? XomifyConstants.xomifyCoverBase64
            if !imageToUpload.isEmpty && imageToUpload != "PASTE_YOUR_BASE64_IMAGE_HERE" {
                do {
                    try await spotifyService.uploadPlaylistCover(playlistId: playlist.id, imageBase64: imageToUpload)
                    print("✅ PlaylistBuilder: Uploaded cover image")
                } catch {
                    // Cover upload failed but playlist was created - don't fail the whole operation
                    print("⚠️ PlaylistBuilder: Cover upload failed - \(error)")
                }
            }
            
            // 5. Success!
            successMessage = "Created '\(name)' with \(tracks.count) tracks!"
            if let urlString = playlist.externalUrls?["spotify"] {
                createdPlaylistUrl = URL(string: urlString)
            }
            
            print("✅ PlaylistBuilder: Created playlist '\(name)' with \(tracks.count) tracks")
            
            // Clear after successful creation
            tracks.removeAll()
            
            // Haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ PlaylistBuilder: Failed to create playlist - \(error)")
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isCreating = false
    }
}
