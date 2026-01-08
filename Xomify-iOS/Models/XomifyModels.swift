import Foundation

// MARK: - User Enrollment

struct XomifyUser: Codable {
    let email: String
    let userId: String
    let displayName: String?
    let refreshToken: String?
    let active: Bool
    let activeWrapped: Bool?
    let activeReleaseRadar: Bool?
    let releaseRadarId: String?
    let updatedAt: String?
}

struct UserEnrollmentResponse: Codable {
    let active: Bool
    let activeWrapped: Bool
    let activeReleaseRadar: Bool
    let wraps: [MonthlyWrap]?
}

// MARK: - Wrapped

struct MonthlyWrap: Codable, Identifiable {
    let monthKey: String
    let topSongIds: TermData?
    let topArtistIds: TermData?
    let topGenres: TermGenres?
    let playlistId: String?
    let createdAt: String?
    let email: String?  // Optional - not always present
    
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
    struct TermData: Codable {
        let shortTerm: [String]?
        let mediumTerm: [String]?
        let longTerm: [String]?
        // No CodingKeys needed - convertFromSnakeCase handles short_term -> shortTerm
    }
    
    struct TermGenres: Codable {
        let shortTerm: [String: Int]?
        let mediumTerm: [String: Int]?
        let longTerm: [String: Int]?
        // No CodingKeys needed - convertFromSnakeCase handles short_term -> shortTerm
    }
}

// MARK: - Release Radar

struct ReleaseRadarWeek: Codable, Identifiable {
    let email: String
    let weekKey: String
    let releases: [Release]
    let stats: ReleaseStats?
    let playlistId: String?
    let finalized: Bool?
    let lastUpdated: String?
    let createdAt: String?
    
    var id: String { weekKey }
    
    /// Parse weekKey "2024-51" to display date range
    var displayName: String {
        // Simple display for now
        let parts = weekKey.split(separator: "-")
        guard parts.count == 2 else { return weekKey }
        return "Week \(parts[1]), \(parts[0])"
    }
}

struct Release: Codable, Identifiable {
    let id: String
    let name: String
    let artistName: String
    let artistId: String?
    let imageUrl: String?
    let albumType: String?
    let releaseDate: String?
    let totalTracks: String?
    let uri: String?
    
    var image: URL? {
        imageUrl.flatMap { URL(string: $0) }
    }
    
    var totalTracksInt: Int {
        Int(totalTracks ?? "0") ?? 0
    }
    
    var typeDisplay: String {
        switch albumType?.lowercased() {
        case "album": return "Album"
        case "single": return "Single"
        case "appears_on": return "Feature"
        default: return albumType?.capitalized ?? "Release"
        }
    }
}

struct ReleaseStats: Codable {
    let totalTracks: String
    let albumCount: String
    let singleCount: String
    let appearsOnCount: String
    
    // Convenience computed properties for Int values
    var totalTracksInt: Int { Int(totalTracks) ?? 0 }
    var albumCountInt: Int { Int(albumCount) ?? 0 }
    var singleCountInt: Int { Int(singleCount) ?? 0 }
    var appearsOnCountInt: Int { Int(appearsOnCount) ?? 0 }
}

struct ReleaseRadarHistoryResponse: Codable {
    let email: String
    let weeks: [ReleaseRadarWeek]
    let count: Int
    let currentWeek: String
}

struct ReleaseRadarLiveResponse: Codable {
    let email: String
    let weekKey: String
    let week: ReleaseRadarWeek
    let source: String
    let finalized: Bool
    let weeksSaved: Int?
}

struct ReleaseRadarCheckResponse: Codable {
    let email: String
    let hasHistory: Bool
    let currentWeek: String
    let currentWeekNeedsRefresh: Bool
}

// MARK: - Genre

struct Genre: Identifiable {
    let name: String
    let count: Int
    
    var id: String { name }
}

extension MonthlyWrap.TermGenres {
    /// Convert genre dict to sorted array
    func toSortedGenres(term: TimeRange) -> [Genre] {
        let dict: [String: Int]?
        switch term {
        case .shortTerm: dict = shortTerm
        case .mediumTerm: dict = mediumTerm
        case .longTerm: dict = longTerm
        }
        
        guard let genres = dict else { return [] }
        
        return genres
            .map { Genre(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}
