import Foundation

/// ViewModel for Wrapped screen
@Observable
final class WrappedViewModel {
    
    // MARK: - Properties
    
    var wraps: [MonthlyWrap] = []
    var selectedWrap: MonthlyWrap?
    var selectedTab: WrappedTab = .tracks
    
    // Resolved Spotify data for the selected wrap
    var tracks: [SpotifyTrack] = []
    var artists: [SpotifyArtist] = []
    var genres: [GenreCount] = []
    
    var isLoading = false
    var isLoadingDetails = false
    var errorMessage: String?
    
    private let xomifyService = XomifyService.shared
    private let spotifyService = SpotifyService.shared
    
    // Cache resolved data per wrap
    private var tracksCache: [String: [SpotifyTrack]] = [:]
    private var artistsCache: [String: [SpotifyArtist]] = [:]
    
    // MARK: - Enums
    
    enum WrappedTab: String, CaseIterable {
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
    
    // MARK: - Computed
    
    var hasWraps: Bool {
        !wraps.isEmpty
    }
    
    var selectedWrapDisplay: String {
        selectedWrap?.displayName ?? "Select Month"
    }
    
    // MARK: - Actions
    
    @MainActor
    func loadWraps() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        print("🚀 Wrapped: Loading wraps...")
        
        do {
            wraps = try await xomifyService.getWraps()
            print("✅ Wrapped: Got \(wraps.count) wraps")
            
            // Sort by most recent first
            wraps.sort { $0.monthKey > $1.monthKey }
            
            // Select most recent wrap by default
            if let first = wraps.first {
                selectedWrap = first
                isLoading = false  // Set loading false before loading details
                await loadWrapDetails(first)
            } else {
                isLoading = false
            }
        } catch {
            print("❌ Wrapped error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    @MainActor
    func selectWrap(_ wrap: MonthlyWrap) async {
        guard selectedWrap?.monthKey != wrap.monthKey else { return }
        selectedWrap = wrap
        await loadWrapDetails(wrap)
    }
    
    @MainActor
    func onTabChange(_ tab: WrappedTab) {
        selectedTab = tab
    }
    
    @MainActor
    private func loadWrapDetails(_ wrap: MonthlyWrap) async {
        isLoadingDetails = true
        
        print("🚀 Wrapped: Loading details for \(wrap.monthKey)...")
        
        do {
            // Get the track IDs for short_term
            let trackIds = wrap.topSongIds?.shortTerm ?? []
            print("   Track IDs count: \(trackIds.count)")
            
            // Load tracks if we have IDs and not cached
            if !trackIds.isEmpty {
                if let cached = tracksCache[wrap.monthKey] {
                    tracks = cached
                    print("✅ Wrapped: Using cached tracks (\(tracks.count))")
                } else {
                    print("🚀 Wrapped: Fetching \(trackIds.count) tracks from Spotify...")
                    let fetchedTracks = try await spotifyService.getTracks(ids: trackIds)
                    print("   Fetched \(fetchedTracks.count) tracks from Spotify")
                    // Sort by original order
                    tracks = trackIds.compactMap { id in
                        fetchedTracks.first { $0.id == id }
                    }
                    tracksCache[wrap.monthKey] = tracks
                    print("✅ Wrapped: Got \(tracks.count) tracks after sorting")
                }
            } else {
                tracks = []
                print("⚠️ Wrapped: No track IDs in wrap data")
            }
            
            // Get the artist IDs for short_term
            let artistIds = wrap.topArtistIds?.shortTerm ?? []
            print("   Artist IDs count: \(artistIds.count)")
            
            // Load artists if we have IDs and not cached
            if !artistIds.isEmpty {
                if let cached = artistsCache[wrap.monthKey] {
                    artists = cached
                    print("✅ Wrapped: Using cached artists (\(artists.count))")
                } else {
                    print("🚀 Wrapped: Fetching \(artistIds.count) artists from Spotify...")
                    let fetchedArtists = try await spotifyService.getArtists(ids: artistIds)
                    print("   Fetched \(fetchedArtists.count) artists from Spotify")
                    // Sort by original order
                    artists = artistIds.compactMap { id in
                        fetchedArtists.first { $0.id == id }
                    }
                    artistsCache[wrap.monthKey] = artists
                    print("✅ Wrapped: Got \(artists.count) artists after sorting")
                }
            } else {
                artists = []
                print("⚠️ Wrapped: No artist IDs in wrap data")
            }
            
            // Load genres from the wrap data
            if let topGenres = wrap.topGenres?.shortTerm {
                genres = topGenres
                    .map { GenreCount(name: $0.key, count: $0.value) }
                    .sorted { $0.count > $1.count }
                print("✅ Wrapped: Got \(genres.count) genres")
            } else {
                genres = []
                print("⚠️ Wrapped: No genre data in wrap")
            }
            
        } catch {
            print("❌ Wrapped details error: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoadingDetails = false
        print("📊 Wrapped: Final state - tracks: \(tracks.count), artists: \(artists.count), genres: \(genres.count)")
    }
}
