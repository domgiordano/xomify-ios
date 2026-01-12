import Foundation

// MARK: - Xomify User

struct XomifyUser: Codable, Sendable {
    let email: String?
    let active: Bool?
    let activeWrapped: Bool?
    let activeReleaseRadar: Bool?
    let refreshToken: String?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Release Radar

/// Response from GET /release-radar/history
struct ReleaseRadarHistoryResponse: Codable, Sendable {
    let email: String?
    let weeks: [ReleaseRadarWeek]?
    let count: Int?
    let currentWeek: String?
    let currentWeekDisplay: String?
}

/// Response from GET /release-radar/check
struct ReleaseRadarCheckResponse: Codable, Sendable {
    let email: String?
    let enrolled: Bool?
    let hasHistory: Bool?
    let currentWeek: String?
    let currentWeekDisplay: String?
    let weekStartDate: String?
    let weekEndDate: String?
}

/// A single week of release radar data
struct ReleaseRadarWeek: Codable, Identifiable, Sendable {
    let weekKey: String
    let weekDisplay: String?
    let startDate: String?
    let endDate: String?
    let releases: [ReleaseRadarRelease]?
    let stats: ReleaseRadarStats?
    let playlistId: String?
    let createdAt: String?
    
    var id: String { weekKey }
    
    /// Display name - use weekDisplay from API or format from weekKey
    var displayName: String {
        if let display = weekDisplay, !display.isEmpty {
            return display
        }
        // Fallback: format weekKey "2025-02" as "Week 2, 2025"
        let parts = weekKey.split(separator: "-")
        guard parts.count == 2 else { return weekKey }
        return "Week \(parts[1]), \(parts[0])"
    }
    
    /// Get date range string from startDate/endDate
    var dateRange: String? {
        guard let start = startDate, let end = endDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        
        guard let startParsed = formatter.date(from: start),
              let endParsed = formatter.date(from: end) else { return nil }
        
        return "\(displayFormatter.string(from: startParsed)) - \(displayFormatter.string(from: endParsed))"
    }
}

/// Stats stored with each week in DynamoDB
/// Note: DynamoDB returns numbers as strings, so we decode as String and convert
struct ReleaseRadarStats: Codable, Sendable {
    let artistCount: Int?
    let releaseCount: Int?
    let trackCount: Int?
    let albumCount: Int?
    let singleCount: Int?
    
    // Custom decoding to handle string numbers from DynamoDB
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        artistCount = Self.decodeIntOrString(from: container, key: .artistCount)
        releaseCount = Self.decodeIntOrString(from: container, key: .releaseCount)
        trackCount = Self.decodeIntOrString(from: container, key: .trackCount)
        albumCount = Self.decodeIntOrString(from: container, key: .albumCount)
        singleCount = Self.decodeIntOrString(from: container, key: .singleCount)
    }
    
    private static func decodeIntOrString(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        // Try Int first
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        }
        // Fall back to String and convert
        if let stringValue = try? container.decode(String.self, forKey: key) {
            return Int(stringValue)
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case artistCount, releaseCount, trackCount, albumCount, singleCount
    }
}

/// A single release (album/single/EP)
/// Note: All fields are optional to handle varying API responses
/// DynamoDB returns numbers as strings, so totalTracks needs special handling
struct ReleaseRadarRelease: Codable, Identifiable, Sendable {
    // Primary identifier - try albumId first, fall back to id
    let albumId: String?
    let albumName: String?
    let albumType: String?
    let artistId: String?
    let artistName: String?
    let releaseDate: String?
    let totalTracks: Int?
    let imageUrl: String?
    let spotifyUrl: String?
    let uri: String?
    
    // Fallback fields (in case API uses different names)
    let id: String?
    let name: String?
    
    // Custom decoding to handle totalTracks as string or int
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        albumId = try container.decodeIfPresent(String.self, forKey: .albumId)
        albumName = try container.decodeIfPresent(String.self, forKey: .albumName)
        albumType = try container.decodeIfPresent(String.self, forKey: .albumType)
        artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        artistName = try container.decodeIfPresent(String.self, forKey: .artistName)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        spotifyUrl = try container.decodeIfPresent(String.self, forKey: .spotifyUrl)
        uri = try container.decodeIfPresent(String.self, forKey: .uri)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        
        // Handle totalTracks as Int or String
        if let intValue = try? container.decode(Int.self, forKey: .totalTracks) {
            totalTracks = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .totalTracks) {
            totalTracks = Int(stringValue)
        } else {
            totalTracks = nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case albumId, albumName, albumType, artistId, artistName
        case releaseDate, totalTracks, imageUrl, spotifyUrl, uri
        case id, name
    }
    
    // Identifiable conformance - use albumId or fall back to id
    var identifier: String {
        albumId ?? id ?? UUID().uuidString
    }
    
    // For ForEach - use computed identifier
    // Note: Can't use 'id' directly as it conflicts with the optional 'id' property
    
    var image: URL? {
        guard let urlString = imageUrl else { return nil }
        return URL(string: urlString)
    }
    
    var spotify: URL? {
        guard let urlString = spotifyUrl else { return nil }
        return URL(string: urlString)
    }
    
    /// Get display name - try albumName first, fall back to name
    var displayName: String {
        albumName ?? name ?? "Unknown Album"
    }
    
    /// Get display artist
    var displayArtist: String {
        artistName ?? "Unknown Artist"
    }
}

// Extend to provide proper Identifiable id
extension ReleaseRadarRelease {
    // This creates a stable id for ForEach
    var stableId: String {
        albumId ?? id ?? UUID().uuidString
    }
}

// MARK: - Release (alias for ViewModel compatibility)

typealias Release = ReleaseRadarRelease

// MARK: - ReleaseStats (computed stats for ViewModel)

struct ReleaseStats: Sendable {
    let artistCount: Int
    let releaseCount: Int
    let trackCount: Int
    let albumCount: Int
    let singleCount: Int
    
    init(artistCount: Int = 0, releaseCount: Int = 0, trackCount: Int = 0, albumCount: Int = 0, singleCount: Int = 0) {
        self.artistCount = artistCount
        self.releaseCount = releaseCount
        self.trackCount = trackCount
        self.albumCount = albumCount
        self.singleCount = singleCount
    }
    
    init(from releases: [ReleaseRadarRelease]) {
        self.artistCount = Set(releases.compactMap { $0.artistId }).count
        self.releaseCount = releases.count
        self.trackCount = releases.reduce(0) { $0 + ($1.totalTracks ?? 0) }
        self.albumCount = releases.filter { $0.albumType?.lowercased() == "album" }.count
        self.singleCount = releases.filter { $0.albumType?.lowercased() == "single" }.count
    }
    
    init(from stats: ReleaseRadarStats?) {
        self.artistCount = stats?.artistCount ?? 0
        self.releaseCount = stats?.releaseCount ?? 0
        self.trackCount = stats?.trackCount ?? 0
        self.albumCount = stats?.albumCount ?? 0
        self.singleCount = stats?.singleCount ?? 0
    }
}

// MARK: - Wrapped

struct MonthlyWrap: Codable, Identifiable, Sendable {
    let monthKey: String
    let topSongIds: TermData?
    let topArtistIds: TermData?
    let topGenres: TermGenres?
    let playlistId: String?
    let createdAt: String?
    let email: String?
    
    var id: String { monthKey }
    
    /// Parse monthKey "2024-12" to display "December 2024"
    var displayName: String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else {
            return monthKey
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        var components = DateComponents()
        components.year = year
        components.month = month
        
        if let date = Calendar.current.date(from: components) {
            return dateFormatter.string(from: date)
        }
        return monthKey
    }
    
    // TermData uses snake_case keys in JSON (short_term, medium_term, long_term)
    // convertFromSnakeCase in decoder handles this automatically
    struct TermData: Codable, Sendable {
        let shortTerm: [String]?
        let mediumTerm: [String]?
        let longTerm: [String]?
    }
    
    struct TermGenres: Codable, Sendable {
        let shortTerm: [String: Int]?
        let mediumTerm: [String: Int]?
        let longTerm: [String: Int]?
    }
}

// MARK: - Wrapped Data Response

struct WrappedDataResponse: Codable, Sendable {
    let active: Bool
    let activeWrapped: Bool
    let activeReleaseRadar: Bool
    let wraps: [MonthlyWrap]?
}

struct EmptyResponse: Codable, Sendable {}
