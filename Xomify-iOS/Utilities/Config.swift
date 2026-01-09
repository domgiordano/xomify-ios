import Foundation

/// App configuration loaded from Secrets.xcconfig
/// Using nonisolated to allow access from actors
enum Config {
    
    // MARK: - Spotify
    
    nonisolated(unsafe) static var spotifyClientId: String {
        Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_ID") as? String ?? ""
    }
    
    nonisolated(unsafe) static var spotifyRedirectUri: String {
        Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_REDIRECT_URI") as? String ?? "xomify://callback"
    }
    
    // MARK: - Xomify Backend
    
    nonisolated(unsafe) static var xomifyApiUrl: String {
        Bundle.main.object(forInfoDictionaryKey: "XOMIFY_API_URL") as? String ?? "https://1hm6iwckle.execute-api.us-east-1.amazonaws.com/dev"
    }
    
    nonisolated(unsafe) static var xomifyApiToken: String {
        Bundle.main.object(forInfoDictionaryKey: "XOMIFY_API_TOKEN") as? String ?? ""
    }
    
    // MARK: - Spotify API (constants - safe to access anywhere)
    
    static let spotifyApiBaseUrl = "https://api.spotify.com/v1"
    static let spotifyAuthUrl = "https://accounts.spotify.com/authorize"
    static let spotifyTokenUrl = "https://accounts.spotify.com/api/token"
    
    // MARK: - Scopes
    
    static let spotifyScopes = [
        "user-read-private",
        "user-read-email",
        "user-top-read",
        "user-follow-read",
        "user-follow-modify",
        "playlist-read-private",
        "playlist-read-collaborative",
        "playlist-modify-public",
        "playlist-modify-private",
        "user-library-read"
    ].joined(separator: " ")
}
