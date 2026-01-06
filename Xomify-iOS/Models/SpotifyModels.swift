import Foundation

// MARK: - User

struct SpotifyUser: Codable, Identifiable, Sendable {
    let id: String
    let displayName: String?
    let email: String?
    let images: [SpotifyImage]?
    let followers: Followers?
    let country: String?
    let product: String?
    
    var profileImageUrl: URL? {
        guard let urlString = images?.first?.url else { return nil }
        return URL(string: urlString)
    }
    
    struct Followers: Codable, Sendable {
        let total: Int?
    }
}

// MARK: - Image

struct SpotifyImage: Codable, Sendable {
    let url: String
    let height: Int?
    let width: Int?
}

// MARK: - Track

struct SpotifyTrack: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let uri: String
    let durationMs: Int
    let explicit: Bool?
    let popularity: Int?
    let previewUrl: String?
    let album: SpotifyAlbum?
    let artists: [SpotifyArtist]
    let externalUrls: ExternalUrls?
    
    var imageUrl: URL? {
        guard let urlString = album?.images?.first?.url else { return nil }
        return URL(string: urlString)
    }
    
    var artistNames: String {
        artists.map { $0.name }.joined(separator: ", ")
    }
    
    var duration: String {
        let minutes = durationMs / 60000
        let seconds = (durationMs % 60000) / 1000
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Album

struct SpotifyAlbum: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let uri: String?
    let albumType: String?
    let totalTracks: Int?
    let releaseDate: String?
    let releaseDatePrecision: String?
    let images: [SpotifyImage]?
    let artists: [SpotifyArtist]?
    let externalUrls: ExternalUrls?
    
    var imageUrl: URL? {
        guard let urlString = images?.first?.url else { return nil }
        return URL(string: urlString)
    }
    
    var artistNames: String {
        artists?.map { $0.name }.joined(separator: ", ") ?? ""
    }
    
    var year: String? {
        guard let date = releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}

// MARK: - Artist

struct SpotifyArtist: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let uri: String?
    let genres: [String]?
    let popularity: Int?
    let followers: SpotifyUser.Followers?
    let images: [SpotifyImage]?
    let externalUrls: ExternalUrls?
    
    var imageUrl: URL? {
        guard let urlString = images?.first?.url else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - Playlist

struct SpotifyPlaylist: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let uri: String?
    let images: [SpotifyImage]?
    let owner: PlaylistOwner?
    let tracks: PlaylistTracks?
    let isPublic: Bool?
    let collaborative: Bool?
    let externalUrls: ExternalUrls?
    
    var imageUrl: URL? {
        guard let urlString = images?.first?.url else { return nil }
        return URL(string: urlString)
    }
    
    struct PlaylistOwner: Codable, Sendable {
        let id: String
        let displayName: String?
    }
    
    struct PlaylistTracks: Codable, Sendable {
        let total: Int
        let items: [PlaylistTrackItem]?
    }
    
    struct PlaylistTrackItem: Codable, Sendable {
        let track: SpotifyTrack?
        let addedAt: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, uri, images, owner, tracks, collaborative, externalUrls
        case isPublic = "public"
    }
}

// MARK: - External URLs

struct ExternalUrls: Codable, Sendable {
    let spotify: String?
}

// MARK: - Paging Objects

struct PagingObject<T: Codable & Sendable>: Codable, Sendable {
    let items: [T]
    let total: Int
    let limit: Int
    let offset: Int
    let next: String?
    let previous: String?
}

struct CursorPagingObject<T: Codable & Sendable>: Codable, Sendable {
    let items: [T]
    let total: Int?
    let limit: Int
    let next: String?
    let cursors: Cursors?
    
    struct Cursors: Codable, Sendable {
        let after: String?
        let before: String?
    }
}

// MARK: - API Response Types

struct TopTracksResponse: Codable, Sendable {
    let items: [SpotifyTrack]
    let total: Int
    let limit: Int
    let offset: Int
}

struct TopArtistsResponse: Codable, Sendable {
    let items: [SpotifyArtist]
    let total: Int
    let limit: Int
    let offset: Int
}

struct FollowingArtistsResponse: Codable, Sendable {
    let artists: ArtistsCursorPaging
    
    struct ArtistsCursorPaging: Codable, Sendable {
        let items: [SpotifyArtist]
        let total: Int?
        let limit: Int
        let next: String?
        let cursors: Cursors?
        
        struct Cursors: Codable, Sendable {
            let after: String?
            let before: String?
        }
    }
}

struct ArtistAlbumsResponse: Codable, Sendable {
    let items: [SpotifyAlbum]
    let total: Int
    let limit: Int
    let offset: Int
    let next: String?
}

struct MultipleAlbumsResponse: Codable, Sendable {
    let albums: [SpotifyAlbum?]
}

struct MultipleArtistsResponse: Codable, Sendable {
    let artists: [SpotifyArtist?]
}

struct ArtistTopTracksResponse: Codable, Sendable {
    let tracks: [SpotifyTrack]
}

struct AlbumTracksResponse: Codable, Sendable {
    let items: [SpotifyTrack]
    let total: Int
    let limit: Int
    let offset: Int
}

struct MultipleTracksResponse: Codable, Sendable {
    let tracks: [SpotifyTrack?]
}

struct SearchResponse: Codable, Sendable {
    let tracks: SearchTracks?
    let artists: SearchArtists?
    let albums: SearchAlbums?
    
    struct SearchTracks: Codable, Sendable {
        let items: [SpotifyTrack]
        let total: Int
    }
    
    struct SearchArtists: Codable, Sendable {
        let items: [SpotifyArtist]
        let total: Int
    }
    
    struct SearchAlbums: Codable, Sendable {
        let items: [SpotifyAlbum]
        let total: Int
    }
}

struct PlaylistSnapshotResponse: Codable, Sendable {
    let snapshotId: String?
    
    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
    }
}

// MARK: - Time Range

enum TimeRange: String, CaseIterable, Sendable {
    case shortTerm = "short_term"
    case mediumTerm = "medium_term"
    case longTerm = "long_term"
    
    var displayName: String {
        switch self {
        case .shortTerm: return "Last 4 Weeks"
        case .mediumTerm: return "Last 6 Months"
        case .longTerm: return "All Time"
        }
    }
}
