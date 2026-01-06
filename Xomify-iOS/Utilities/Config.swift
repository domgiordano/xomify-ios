import Foundation

/// App configuration - reads secrets from Info.plist (populated by Xcconfig)
enum Config {
    
    // MARK: - Spotify Configuration
    
    static var spotifyClientId: String {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientId") as? String,
              !clientId.isEmpty,
              !clientId.contains("your_") else {
            fatalError("SpotifyClientId not configured in Info.plist. Check your Secrets.xcconfig file.")
        }
        return clientId
    }
    
    static var spotifyClientSecret: String {
        guard let secret = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientSecret") as? String,
              !secret.isEmpty,
              !secret.contains("your_") else {
            fatalError("SpotifyClientSecret not configured in Info.plist. Check your Secrets.xcconfig file.")
        }
        return secret
    }
    
    static let spotifyRedirectURI = URL(string: "xomify://callback")!
    
    static let spotifyScopes: [String] = [
        "user-read-private",
        "user-read-email",
        "user-library-read",
        "user-top-read",
        "playlist-modify-public",
        "playlist-modify-private",
        "playlist-read-private",
        "playlist-read-collaborative",
        "ugc-image-upload",
        "user-follow-read",
        "user-follow-modify",
        "user-modify-playback-state",
        "user-read-playback-state",
        "streaming"
    ]
    
    /// Scopes joined for URL encoding
    static var spotifyScopesString: String {
        spotifyScopes.joined(separator: " ")
    }
    
    // MARK: - Xomify API Configuration
    
    static var xomifyApiToken: String {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "XomifyApiToken") as? String,
              !token.isEmpty,
              !token.contains("your_") else {
            fatalError("XomifyApiToken not configured in Info.plist. Check your Secrets.xcconfig file.")
        }
        return token
    }
    
    static var xomifyApiId: String {
        guard let apiId = Bundle.main.object(forInfoDictionaryKey: "XomifyApiId") as? String,
              !apiId.isEmpty,
              !apiId.contains("your_") else {
            fatalError("XomifyApiId not configured in Info.plist. Check your Secrets.xcconfig file.")
        }
        return apiId
    }
    
    static var xomifyApiBaseUrl: String {
        "https://\(xomifyApiId).execute-api.us-east-1.amazonaws.com/dev"
    }
    
    // MARK: - Spotify API URLs
    
    static let spotifyAccountsBaseUrl = "https://accounts.spotify.com"
    static let spotifyApiBaseUrl = "https://api.spotify.com/v1"
    
    // MARK: - Spotify Auth URLs
    
    static var spotifyAuthUrl: URL {
        var components = URLComponents(string: "\(spotifyAccountsBaseUrl)/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: spotifyClientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: spotifyRedirectURI.absoluteString),
            URLQueryItem(name: "scope", value: spotifyScopesString),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        return components.url!
    }
}
