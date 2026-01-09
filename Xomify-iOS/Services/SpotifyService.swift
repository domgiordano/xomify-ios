import Foundation

/// Service for Spotify API calls
actor SpotifyService {
    
    // MARK: - Singleton
    
    static let shared = SpotifyService()
    
    private let network = NetworkService.shared
    
    private init() {}
    
    // MARK: - User Profile
    
    func getCurrentUser() async throws -> SpotifyUser {
        try await network.spotifyGet("/me")
    }
    
    // MARK: - Top Items
    
    func getTopTracks(timeRange: TimeRange = .shortTerm, limit: Int = 25) async throws -> [SpotifyTrack] {
        let response: TopTracksResponse = try await network.spotifyGet(
            "/me/top/tracks?time_range=\(timeRange.rawValue)&limit=\(limit)"
        )
        return response.items
    }
    
    func getTopArtists(timeRange: TimeRange = .shortTerm, limit: Int = 25) async throws -> [SpotifyArtist] {
        let response: TopArtistsResponse = try await network.spotifyGet(
            "/me/top/artists?time_range=\(timeRange.rawValue)&limit=\(limit)"
        )
        return response.items
    }
    
    func getAllTopTracks(limit: Int = 25) async throws -> (shortTerm: [SpotifyTrack], mediumTerm: [SpotifyTrack], longTerm: [SpotifyTrack]) {
        async let short = getTopTracks(timeRange: .shortTerm, limit: limit)
        async let medium = getTopTracks(timeRange: .mediumTerm, limit: limit)
        async let long = getTopTracks(timeRange: .longTerm, limit: limit)
        
        return try await (short, medium, long)
    }
    
    func getAllTopArtists(limit: Int = 25) async throws -> (shortTerm: [SpotifyArtist], mediumTerm: [SpotifyArtist], longTerm: [SpotifyArtist]) {
        async let short = getTopArtists(timeRange: .shortTerm, limit: limit)
        async let medium = getTopArtists(timeRange: .mediumTerm, limit: limit)
        async let long = getTopArtists(timeRange: .longTerm, limit: limit)
        
        return try await (short, medium, long)
    }
    
    // MARK: - Following
    
    func getFollowedArtists() async throws -> [SpotifyArtist] {
        var allArtists: [SpotifyArtist] = []
        var afterCursor: String? = nil
        
        repeat {
            var endpoint = "/me/following?type=artist&limit=50"
            if let cursor = afterCursor {
                endpoint += "&after=\(cursor)"
            }
            
            let response: FollowingArtistsResponse = try await network.spotifyGet(endpoint)
            allArtists.append(contentsOf: response.artists.items)
            afterCursor = response.artists.cursors?.after
            
        } while afterCursor != nil
        
        return allArtists
    }
    
    func isFollowing(artistIds: [String]) async throws -> [Bool] {
        let ids = artistIds.joined(separator: ",")
        return try await network.spotifyGet("/me/following/contains?type=artist&ids=\(ids)")
    }
    
    func followArtist(id: String) async throws {
        try await network.spotifyPut("/me/following?type=artist&ids=\(id)", body: [:])
    }
    
    func unfollowArtist(id: String) async throws {
        try await network.spotifyDelete("/me/following?type=artist&ids=\(id)")
    }
    
    // MARK: - Artists
    
    func getArtist(id: String) async throws -> SpotifyArtist {
        try await network.spotifyGet("/artists/\(id)")
    }
    
    func getArtists(ids: [String]) async throws -> [SpotifyArtist] {
        var allArtists: [SpotifyArtist] = []
        
        for chunk in ids.chunked(into: 50) {
            let idsParam = chunk.joined(separator: ",")
            let response: MultipleArtistsResponse = try await network.spotifyGet("/artists?ids=\(idsParam)")
            allArtists.append(contentsOf: response.artists.compactMap { $0 })
        }
        
        return allArtists
    }
    
    func getArtistAlbums(
        id: String,
        includeGroups: [String] = ["album", "single"],
        limit: Int = 20
    ) async throws -> [SpotifyAlbum] {
        let groups = includeGroups.joined(separator: ",")
        let response: ArtistAlbumsResponse = try await network.spotifyGet(
            "/artists/\(id)/albums?include_groups=\(groups)&limit=\(limit)"
        )
        return response.items
    }
    
    func getArtistTopTracks(id: String, market: String = "US") async throws -> [SpotifyTrack] {
        let response: ArtistTopTracksResponse = try await network.spotifyGet(
            "/artists/\(id)/top-tracks?market=\(market)"
        )
        return response.tracks
    }
    
    // MARK: - Albums
    
    func getAlbum(id: String) async throws -> SpotifyAlbum {
        try await network.spotifyGet("/albums/\(id)")
    }
    
    func getAlbums(ids: [String]) async throws -> [SpotifyAlbum] {
        var allAlbums: [SpotifyAlbum] = []
        
        for chunk in ids.chunked(into: 20) {
            let idsParam = chunk.joined(separator: ",")
            let response: MultipleAlbumsResponse = try await network.spotifyGet("/albums?ids=\(idsParam)")
            allAlbums.append(contentsOf: response.albums.compactMap { $0 })
        }
        
        return allAlbums
    }
    
    func getAlbumTracks(id: String, limit: Int = 50) async throws -> [SpotifyTrack] {
        let response: AlbumTracksResponse = try await network.spotifyGet(
            "/albums/\(id)/tracks?limit=\(limit)"
        )
        return response.items
    }
    
    // MARK: - Tracks
    
    func getTrack(id: String) async throws -> SpotifyTrack {
        try await network.spotifyGet("/tracks/\(id)")
    }
    
    func getTracks(ids: [String]) async throws -> [SpotifyTrack] {
        var allTracks: [SpotifyTrack] = []
        
        for chunk in ids.chunked(into: 50) {
            let idsParam = chunk.joined(separator: ",")
            let response: MultipleTracksResponse = try await network.spotifyGet("/tracks?ids=\(idsParam)")
            allTracks.append(contentsOf: response.tracks.compactMap { $0 })
        }
        
        return allTracks
    }
    
    // MARK: - Playlists
    
    func getUserPlaylists(limit: Int = 50) async throws -> [SpotifyPlaylist] {
        let response: PlaylistsResponse = try await network.spotifyGet(
            "/me/playlists?limit=\(limit)"
        )
        return response.items
    }
    
    func getPlaylist(id: String) async throws -> SpotifyPlaylist {
        try await network.spotifyGet("/playlists/\(id)")
    }
    
    func createPlaylist(
        userId: String,
        name: String,
        description: String,
        isPublic: Bool = true
    ) async throws -> SpotifyPlaylist {
        try await network.spotifyPost(
            "/users/\(userId)/playlists",
            body: [
                "name": name,
                "description": description,
                "public": isPublic
            ]
        )
    }
    
    func addTracksToPlaylist(playlistId: String, trackUris: [String]) async throws {
        for chunk in trackUris.chunked(into: 100) {
            let _: PlaylistSnapshotResponse = try await network.spotifyPost(
                "/playlists/\(playlistId)/tracks",
                body: ["uris": chunk]
            )
        }
    }
    
    // MARK: - Search
    
    func search(
        query: String,
        types: [String] = ["track", "artist", "album"],
        limit: Int = 20
    ) async throws -> SearchResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let typesParam = types.joined(separator: ",")
        return try await network.spotifyGet(
            "/search?q=\(encodedQuery)&type=\(typesParam)&limit=\(limit)"
        )
    }
    
    func searchTracks(query: String, limit: Int = 20) async throws -> [SpotifyTrack] {
        let response = try await search(query: query, types: ["track"], limit: limit)
        return response.tracks?.items ?? []
    }
    
    func searchArtists(query: String, limit: Int = 20) async throws -> [SpotifyArtist] {
        let response = try await search(query: query, types: ["artist"], limit: limit)
        return response.artists?.items ?? []
    }
    
    func searchAlbums(query: String, limit: Int = 20) async throws -> [SpotifyAlbum] {
        let response = try await search(query: query, types: ["album"], limit: limit)
        return response.albums?.items ?? []
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
