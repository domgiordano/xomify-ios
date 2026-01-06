import Foundation
import AuthenticationServices

/// Handles Spotify OAuth authentication
/// Exchanges tokens directly with Spotify (same pattern as Angular app)
@Observable
final class AuthService: NSObject {
    
    // MARK: - Properties
    
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?
    
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var tokenExpirationDate: Date?
    
    // MARK: - Keychain Keys
    
    private enum KeychainKey {
        static let accessToken = "com.xomify.accessToken"
        static let refreshToken = "com.xomify.refreshToken"
        static let tokenExpiration = "com.xomify.tokenExpiration"
    }
    
    // MARK: - Singleton
    
    static let shared = AuthService()
    
    private override init() {
        super.init()
        loadTokensFromKeychain()
    }
    
    // MARK: - Public Methods
    
    /// Check if we have a valid token
    var hasValidToken: Bool {
        guard let token = accessToken,
              let expiration = tokenExpirationDate,
              !token.isEmpty else {
            return false
        }
        // Consider token invalid if it expires in less than 5 minutes
        return expiration > Date().addingTimeInterval(300)
    }
    
    /// Get a valid access token, refreshing if needed
    func getValidAccessToken() async throws -> String {
        // If token is still valid, return it
        if hasValidToken, let token = accessToken {
            return token
        }
        
        // Try to refresh
        if let refresh = refreshToken {
            try await refreshAccessToken(refreshToken: refresh)
            if let token = accessToken {
                return token
            }
        }
        
        throw AuthError.notAuthenticated
    }
    
    /// Start the OAuth flow using ASWebAuthenticationSession
    @MainActor
    func login() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Get authorization code
            let code = try await performAuthSession()
            
            // Exchange code for tokens directly with Spotify
            try await exchangeCodeForTokens(code: code)
            
            isAuthenticated = true
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Clear all tokens and log out
    func logout() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
        isAuthenticated = false
        
        // Clear keychain
        deleteFromKeychain(key: KeychainKey.accessToken)
        deleteFromKeychain(key: KeychainKey.refreshToken)
        deleteFromKeychain(key: KeychainKey.tokenExpiration)
    }
    
    // MARK: - Private Methods
    
    /// Perform the web auth session
    @MainActor
    private func performAuthSession() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: Config.spotifyAuthUrl,
                callbackURLScheme: "xomify"
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: AuthError.authSessionFailed(error.localizedDescription))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noAuthCode)
                    return
                }
                
                continuation.resume(returning: code)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            if !session.start() {
                continuation.resume(throwing: AuthError.authSessionFailed("Failed to start auth session"))
            }
        }
    }
    
    /// Exchange authorization code for tokens directly with Spotify
    private func exchangeCodeForTokens(code: String) async throws {
        let url = URL(string: "\(Config.spotifyAccountsBaseUrl)/api/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic auth header with client_id:client_secret
        let credentials = "\(Config.spotifyClientId):\(Config.spotifyClientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Form body
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Config.spotifyRedirectURI.absoluteString
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.tokenExchangeFailed
        }
        
        if httpResponse.statusCode != 200 {
            #if DEBUG
            if let errorJson = String(data: data, encoding: .utf8) {
                print("❌ Token exchange failed: \(errorJson)")
            }
            #endif
            throw AuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Store tokens
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken ?? self.refreshToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        // Save to keychain
        saveTokensToKeychain()
    }
    
    /// Refresh the access token using refresh token - directly with Spotify
    private func refreshAccessToken(refreshToken: String) async throws {
        let url = URL(string: "\(Config.spotifyAccountsBaseUrl)/api/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic auth header
        let credentials = "\(Config.spotifyClientId):\(Config.spotifyClientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Form body
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Refresh failed, need to re-auth
            logout()
            throw AuthError.refreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Update tokens
        self.accessToken = tokenResponse.accessToken
        if let newRefresh = tokenResponse.refreshToken {
            self.refreshToken = newRefresh
        }
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        self.isAuthenticated = true
        
        // Save to keychain
        saveTokensToKeychain()
    }
    
    // MARK: - Keychain
    
    private func saveTokensToKeychain() {
        if let accessToken = accessToken {
            saveToKeychain(key: KeychainKey.accessToken, value: accessToken)
        }
        if let refreshToken = refreshToken {
            saveToKeychain(key: KeychainKey.refreshToken, value: refreshToken)
        }
        if let expiration = tokenExpirationDate {
            saveToKeychain(key: KeychainKey.tokenExpiration, value: String(expiration.timeIntervalSince1970))
        }
    }
    
    private func loadTokensFromKeychain() {
        accessToken = loadFromKeychain(key: KeychainKey.accessToken)
        refreshToken = loadFromKeychain(key: KeychainKey.refreshToken)
        
        if let expirationString = loadFromKeychain(key: KeychainKey.tokenExpiration),
           let interval = Double(expirationString) {
            tokenExpirationDate = Date(timeIntervalSince1970: interval)
        }
        
        // Check if we have valid tokens
        isAuthenticated = hasValidToken || refreshToken != nil
    }
    
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Supporting Types

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

enum AuthError: LocalizedError {
    case notAuthenticated
    case userCancelled
    case authSessionFailed(String)
    case noAuthCode
    case tokenExchangeFailed
    case refreshFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        case .userCancelled:
            return "Login was cancelled."
        case .authSessionFailed(let message):
            return "Authentication failed: \(message)"
        case .noAuthCode:
            return "No authorization code received."
        case .tokenExchangeFailed:
            return "Failed to exchange code for tokens."
        case .refreshFailed:
            return "Session expired. Please log in again."
        }
    }
}
